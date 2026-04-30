#!/usr/bin/env python3
"""
Initialize SQLite database with required tables.
This is a simple alternative to using Alembic migrations.
"""
# Import database models
from miss_pauling.shared.database import engine, Base
from miss_pauling.shared.models import User, UserSession

def init_db():
    """Create all tables in the database"""
    print("Creating SQLite database tables...")
    Base.metadata.create_all(bind=engine)
    print("Database tables created successfully.")

if __name__ == "__main__":
    # Get the database URL
    from miss_pauling.shared.database import get_database_url
    db_url = get_database_url()
    print(f"Initializing database at: {db_url}")
    
    # Create tables
    init_db()
    
    # Show success message
    print("\nSQLite database setup completed!")
    print("The application is now ready to connect to the database.")