import uuid
from datetime import datetime, timezone

from sqlalchemy import Integer, String, Float, Text, DateTime, ForeignKey, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class AttendanceRecord(Base):
    """Attendance record created during a bulk-sync from the Flutter app.

    Key dual-timestamp design:
    - `checkin_time` — the real-world timestamp captured **offline** on the device
      when the face was recognized (may predate `sync_time` by hours/days).
    - `sync_time`    — the server timestamp when the record was actually pushed.

    This allows the system to accurately reconstruct real attendance timelines
    even when the device had no network connectivity at scan time.
    """

    __tablename__ = "attendance_records"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        index=True,
    )

    # FK: student (required)
    student_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("students.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # FK: class (optional — a checkin can be free-floating without a class context)
    class_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("classes.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    # Record type: 'checkin' or 'checkout'
    record_type: Mapped[str] = mapped_column(
        String(10), nullable=False, default="checkin"
    )

    # Timestamps
    checkin_time: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )  # Device offline time
    sync_time: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        default=lambda: datetime.now(timezone.utc),
    )  # Server receive time

    # Recognition metadata
    confidence: Mapped[float | None] = mapped_column(Float, nullable=True)
    device_id: Mapped[str | None] = mapped_column(String(255), nullable=True)

    # Status: 'present' | 'absent' | 'late'
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="present"
    )

    # Geo-location
    latitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    longitude: Mapped[float | None] = mapped_column(Float, nullable=True)

    # Snapshot image captured at the moment of recognition
    image_url: Mapped[str | None] = mapped_column(Text, nullable=True)

    # ── Relationships ──────────────────────────────────────────
    student: Mapped["Student"] = relationship(  # noqa: F821
        "Student", back_populates="attendance_records"
    )
    classroom: Mapped["Classroom"] = relationship(  # noqa: F821
        "Classroom", back_populates="attendance_records"
    )

    def __repr__(self) -> str:
        return (
            f"<AttendanceRecord id={self.id} "
            f"student_id={self.student_id} "
            f"type={self.record_type} "
            f"status={self.status}>"
        )
