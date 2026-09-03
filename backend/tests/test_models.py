from app.models import Base


def test_model_metadata_resolves_all_foreign_keys() -> None:
    """Profile updates must not fail while SQLAlchemy orders mapped tables."""

    table_names = {table.fullname for table in Base.metadata.sorted_tables}

    assert {"users", "posts", "friendships"}.issubset(table_names)
