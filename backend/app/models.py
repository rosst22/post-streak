import uuid
from datetime import datetime
from enum import StrEnum

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


class Platform(StrEnum):
    instagram = "instagram"
    tiktok = "tiktok"
    youtube = "youtube"
    other = "other"


class PostFormat(StrEnum):
    post = "post"
    reel = "reel"
    story = "story"
    video = "video"
    short = "short"
    other = "other"


class FriendshipStatus(StrEnum):
    pending = "pending"
    accepted = "accepted"


class ReportReason(StrEnum):
    spam = "spam"
    harassment = "harassment"
    hate_speech = "hate_speech"
    sexual_content = "sexual_content"
    violence = "violence"
    other = "other"


class User(Base):
    __tablename__ = "users"
    __table_args__ = (CheckConstraint("weekly_target BETWEEN 1 AND 100"),)

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("auth.users.id", ondelete="CASCADE"), primary_key=True
    )
    friend_code: Mapped[str] = mapped_column(String(12), unique=True)
    display_name: Mapped[str] = mapped_column(String(80), default="Creator")
    timezone: Mapped[str] = mapped_column(String(64), default="UTC")
    weekly_target: Mapped[int] = mapped_column(Integer, default=3)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class Post(Base):
    __tablename__ = "posts"
    __table_args__ = (
        Index("posts_user_posted_at_idx", "user_id", "posted_at"),
        Index("posts_posted_at_idx", "posted_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE")
    )
    platform: Mapped[Platform] = mapped_column(Enum(Platform, name="platform"))
    posted_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    format: Mapped[PostFormat] = mapped_column(Enum(PostFormat, name="post_format"))
    url: Mapped[str | None] = mapped_column(Text)
    title: Mapped[str | None] = mapped_column(String(300))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class Friendship(Base):
    __tablename__ = "friendships"
    __table_args__ = (
        CheckConstraint("requester_id <> addressee_id", name="different_users"),
        Index("friendships_requester_idx", "requester_id", "status"),
        Index("friendships_addressee_idx", "addressee_id", "status"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True)
    requester_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE")
    )
    addressee_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE")
    )
    status: Mapped[FriendshipStatus] = mapped_column(
        Enum(FriendshipStatus, name="friendship_status")
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class BlockedUser(Base):
    __tablename__ = "blocked_users"
    __table_args__ = (CheckConstraint("blocker_id <> blocked_id", name="different_users"),)

    blocker_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    blocked_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class PostReport(Base):
    __tablename__ = "post_reports"
    __table_args__ = (
        UniqueConstraint("reporter_id", "post_id", name="post_reports_reporter_post_key"),
        Index("post_reports_status_created_idx", "status", "created_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True)
    reporter_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE")
    )
    post_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("posts.id", ondelete="CASCADE")
    )
    reason: Mapped[ReportReason] = mapped_column(Enum(ReportReason, name="report_reason"))
    details: Mapped[str | None] = mapped_column(String(500))
    status: Mapped[str] = mapped_column(String(20), default="open")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
