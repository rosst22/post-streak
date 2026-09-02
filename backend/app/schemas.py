import uuid
from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field, HttpUrl, field_validator

from app.models import FriendshipStatus, Platform, PostFormat, ReportReason


class PostCreate(BaseModel):
    platform: Platform
    posted_at: datetime | None = None
    format: PostFormat = PostFormat.post
    url: HttpUrl | None = None
    title: str | None = Field(default=None, max_length=300)


class Author(BaseModel):
    id: uuid.UUID
    display_name: str


class PostResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_id: uuid.UUID
    platform: Platform
    posted_at: datetime
    format: PostFormat
    url: str | None
    title: str | None
    created_at: datetime
    author: Author | None = None


class WeekCount(BaseModel):
    week_start: date
    count: int


class DayCount(BaseModel):
    date: date
    count: int


class StatsResponse(BaseModel):
    current_streak: int
    longest_streak: int
    weekly_target: int
    current_week_posts: int
    posts_per_week: list[WeekCount]
    heatmap: list[DayCount]


class MeResponse(BaseModel):
    id: uuid.UUID
    display_name: str
    friend_code: str
    timezone: str
    weekly_target: int


class MeUpdate(BaseModel):
    display_name: str = Field(min_length=1, max_length=40)
    timezone: str = Field(min_length=1, max_length=64)
    weekly_target: int = Field(ge=1, le=14)

    @field_validator("display_name")
    @classmethod
    def normalize_display_name(cls, value: str) -> str:
        normalized = " ".join(value.split())
        if not normalized:
            raise ValueError("display_name cannot be blank")
        return normalized


class FriendRequestCreate(BaseModel):
    friend_code: str = Field(min_length=12, max_length=12, pattern=r"^[A-Fa-f0-9]{12}$")


class FriendAcceptCreate(BaseModel):
    friendship_id: uuid.UUID


class FriendResponse(BaseModel):
    friendship_id: uuid.UUID
    user_id: uuid.UUID
    display_name: str
    status: FriendshipStatus
    direction: str


class BlockUserCreate(BaseModel):
    user_id: uuid.UUID


class ContentReportCreate(BaseModel):
    reason: ReportReason
    details: str | None = Field(default=None, max_length=500)


class ActionResponse(BaseModel):
    message: str
