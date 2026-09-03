// Post Streak App Store Connect release helper.
// Credentials are read from ASC_KEY_ID, ASC_ISSUER_ID, and ASC_KEY_PATH.
import { createHash, createSign } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { basename, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';

const APP_ID = '6806101624';
const KEY_ID = process.env.ASC_KEY_ID;
const ISSUER_ID = process.env.ASC_ISSUER_ID;
const KEY_PATH = process.env.ASC_KEY_PATH;
const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = join(HERE, '..', '..');
const SCREENSHOTS = [
  '01-home.png',
  '02-friends-feed.png',
  '03-friend-requests.png',
  '04-settings.png',
].map((name) => join(REPO, 'store-assets', 'ios', name));

if (!KEY_ID || !ISSUER_ID || !KEY_PATH) {
  throw new Error('Set ASC_KEY_ID, ASC_ISSUER_ID, and ASC_KEY_PATH.');
}

const b64url = (value) =>
  Buffer.from(value)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');

function token() {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'ES256', kid: KEY_ID, typ: 'JWT' };
  const payload = {
    iss: ISSUER_ID,
    iat: now,
    exp: now + 1200,
    aud: 'appstoreconnect-v1',
  };
  const body = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(payload))}`;
  const signer = createSign('SHA256');
  signer.update(body);
  const signature = signer.sign({
    key: readFileSync(KEY_PATH),
    dsaEncoding: 'ieee-p1363',
  });
  return `${body}.${b64url(signature)}`;
}

async function api(path, { method = 'GET', body, raw = false } = {}) {
  const url = path.startsWith('http')
    ? path
    : `https://api.appstoreconnect.apple.com/v1${path}`;
  const response = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${token()}`,
      ...(body ? { 'Content-Type': 'application/json' } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (raw) return response;
  const text = await response.text();
  if (!response.ok) {
    throw new Error(`${method} ${path} -> ${response.status}\n${text}`);
  }
  return text ? JSON.parse(text) : null;
}

async function version() {
  const { data } = await api(
    `/apps/${APP_ID}/appStoreVersions?limit=10&fields[appStoreVersions]=versionString,appStoreState,platform,build,appStoreReviewDetail`,
  );
  const result = data.find(
    (item) =>
      item.attributes.platform === 'IOS' &&
      !['READY_FOR_SALE', 'REPLACED_WITH_NEW_VERSION'].includes(
        item.attributes.appStoreState,
      ),
  );
  if (!result) throw new Error('No editable iOS version found.');
  return result;
}

async function localization(versionId) {
  const { data } = await api(
    `/appStoreVersions/${versionId}/appStoreVersionLocalizations?limit=50`,
  );
  const result = data.find((item) => item.attributes.locale === 'en-US');
  if (!result) throw new Error('No en-US version localization found.');
  return result;
}

async function metadata() {
  const editable = await version();
  const localized = await localization(editable.id);
  await api(`/appStoreVersionLocalizations/${localized.id}`, {
    method: 'PATCH',
    body: {
      data: {
        type: 'appStoreVersionLocalizations',
        id: localized.id,
        attributes: {
          description: readFileSync(join(HERE, 'description.txt'), 'utf8').trim(),
          keywords:
            'creator,content,streak,posting,habit,instagram,tiktok,youtube,consistency,schedule',
          promotionalText:
            'Focus on consistency, not vanity metrics. Log what you publish, keep a weekly streak, and stay accountable with friends.',
          supportUrl: 'https://post-streak-api-rosst22.onrender.com/support',
          marketingUrl: 'https://post-streak-api-rosst22.onrender.com/support',
        },
      },
    },
  });

  const { data: infos } = await api(`/apps/${APP_ID}/appInfos?limit=10`);
  const { data: infoLocalizations } = await api(
    `/appInfos/${infos[0].id}/appInfoLocalizations?limit=50`,
  );
  const info = infoLocalizations.find((item) => item.attributes.locale === 'en-US');
  if (!info) throw new Error('No en-US app localization found.');
  await api(`/appInfoLocalizations/${info.id}`, {
    method: 'PATCH',
    body: {
      data: {
        type: 'appInfoLocalizations',
        id: info.id,
        attributes: {
          name: 'Post Streak: Creator Tracker',
          subtitle: 'Build a publishing habit',
          privacyPolicyUrl:
            'https://post-streak-api-rosst22.onrender.com/privacy',
          privacyChoicesUrl:
            'https://post-streak-api-rosst22.onrender.com/privacy',
        },
      },
    },
  });
  console.log('metadata_updated', true);
}

async function screenshots() {
  const editable = await version();
  const localized = await localization(editable.id);
  const { data: sets } = await api(
    `/appStoreVersionLocalizations/${localized.id}/appScreenshotSets?limit=50`,
  );

  for (const set of sets) {
    const { data: oldScreenshots } = await api(
      `/appScreenshotSets/${set.id}/appScreenshots?limit=50`,
    );
    for (const screenshot of oldScreenshots) {
      const response = await api(`/appScreenshots/${screenshot.id}`, {
        method: 'DELETE',
        raw: true,
      });
      if (!response.ok) {
        throw new Error(`Could not delete old screenshot: ${response.status}`);
      }
    }
  }

  let set = sets.find(
    (item) => item.attributes.screenshotDisplayType === 'APP_IPHONE_67',
  );
  if (!set) {
    ({ data: set } = await api('/appScreenshotSets', {
      method: 'POST',
      body: {
        data: {
          type: 'appScreenshotSets',
          attributes: { screenshotDisplayType: 'APP_IPHONE_67' },
          relationships: {
            appStoreVersionLocalization: {
              data: {
                type: 'appStoreVersionLocalizations',
                id: localized.id,
              },
            },
          },
        },
      },
    }));
  }

  for (const file of SCREENSHOTS) {
    const bytes = readFileSync(file);
    const { data: screenshot } = await api('/appScreenshots', {
      method: 'POST',
      body: {
        data: {
          type: 'appScreenshots',
          attributes: { fileName: basename(file), fileSize: bytes.length },
          relationships: {
            appScreenshotSet: {
              data: { type: 'appScreenshotSets', id: set.id },
            },
          },
        },
      },
    });
    for (const operation of screenshot.attributes.uploadOperations) {
      const headers = Object.fromEntries(
        operation.requestHeaders.map((header) => [header.name, header.value]),
      );
      const chunk = bytes.subarray(
        operation.offset,
        operation.offset + operation.length,
      );
      const upload = await fetch(operation.url, {
        method: operation.method,
        headers,
        body: chunk,
      });
      if (!upload.ok) {
        throw new Error(`Upload ${basename(file)} -> ${upload.status}`);
      }
    }
    await api(`/appScreenshots/${screenshot.id}`, {
      method: 'PATCH',
      body: {
        data: {
          type: 'appScreenshots',
          id: screenshot.id,
          attributes: {
            uploaded: true,
            sourceFileChecksum: createHash('md5').update(bytes).digest('hex'),
          },
        },
      },
    });
    console.log('screenshot_uploaded', basename(file));
  }
}

async function selectBuild(buildNumber = '4') {
  const editable = await version();
  const { data: builds } = await api(
    `/apps/${APP_ID}/builds?limit=10`,
  );
  const candidates = builds.filter(
    (build) =>
      build.attributes.version === buildNumber &&
      // Build numbers are strings in App Store Connect.
      build.attributes.processingState === 'VALID',
  );
  if (candidates.length !== 1) {
    throw new Error(`Expected one valid build ${buildNumber}, found ${candidates.length}.`);
  }
  await api(`/appStoreVersions/${editable.id}/relationships/build`, {
    method: 'PATCH',
    body: { data: { type: 'builds', id: candidates[0].id } },
  });
  console.log('build_selected', buildNumber);
}

async function reviewCredentials() {
  const editable = await version();
  const { data: detail } = await api(
    `/appStoreVersions/${editable.id}/appStoreReviewDetail`,
  );
  const password = execFileSync(
    'security',
    [
      'find-generic-password',
      '-a',
      'rosstoma+poststreak-review@gmail.com',
      '-s',
      'PostStreak App Review primary',
      '-w',
    ],
    { encoding: 'utf8' },
  ).trim();
  await api(`/appStoreReviewDetails/${detail.id}`, {
    method: 'PATCH',
    body: {
      data: {
        type: 'appStoreReviewDetails',
        id: detail.id,
        attributes: {
          demoAccountRequired: true,
          demoAccountName: 'rosstoma+poststreak-review@gmail.com',
          demoAccountPassword: password,
        },
      },
    },
  });
  console.log('review_credentials_updated', true);
}

async function status() {
  const editable = await version();
  const localized = await localization(editable.id);
  const { data: sets } = await api(
    `/appStoreVersionLocalizations/${localized.id}/appScreenshotSets?limit=50`,
  );
  const screenshotCounts = [];
  for (const set of sets) {
    const { data: items } = await api(
      `/appScreenshotSets/${set.id}/appScreenshots?limit=50`,
    );
    screenshotCounts.push({
      type: set.attributes.screenshotDisplayType,
      count: items.length,
    });
  }
  const { data: builds } = await api(`/apps/${APP_ID}/builds?limit=10`);
  const { data: submissions } = await api(
    `/apps/${APP_ID}/reviewSubmissions?limit=20&fields[reviewSubmissions]=platform,submittedDate,state`,
  );
  const buildResponse = await api(`/appStoreVersions/${editable.id}/build`);
  const { data: detail } = await api(
    `/appStoreVersions/${editable.id}/appStoreReviewDetail`,
  );
  console.log(
    JSON.stringify(
      {
        versionId: editable.id,
        version: editable.attributes.versionString,
        appStoreState: editable.attributes.appStoreState,
        listing: {
          description: Boolean(localized.attributes.description),
          keywords: Boolean(localized.attributes.keywords),
          promotionalText: Boolean(localized.attributes.promotionalText),
          supportUrl: localized.attributes.supportUrl,
        },
        screenshotCounts,
        selectedBuild: buildResponse.data
          ? {
              id: buildResponse.data.id,
              version: buildResponse.data.attributes.version,
              processingState: buildResponse.data.attributes.processingState,
            }
          : null,
        reviewDetails: {
          demoAccountRequired: detail.attributes.demoAccountRequired,
          hasDemoAccountName: Boolean(detail.attributes.demoAccountName),
          hasDemoAccountPassword: Boolean(detail.attributes.demoAccountPassword),
          hasNotes: Boolean(detail.attributes.notes),
          hasContactEmail: Boolean(detail.attributes.contactEmail),
          hasContactPhone: Boolean(detail.attributes.contactPhone),
          notes: detail.attributes.notes,
        },
        builds: builds.map((build) => ({
          id: build.id,
          version: build.attributes.version,
          processingState: build.attributes.processingState,
        })),
        submissions: submissions.map((submission) => ({
          id: submission.id,
          ...submission.attributes,
        })),
      },
      null,
      2,
    ),
  );
}

const commands = {
  metadata,
  screenshots,
  'select-build': selectBuild,
  'review-credentials': reviewCredentials,
  status,
};
const [command, ...args] = process.argv.slice(2);
if (!commands[command]) {
  throw new Error(`Use one of: ${Object.keys(commands).join(', ')}`);
}
await commands[command](...args);
