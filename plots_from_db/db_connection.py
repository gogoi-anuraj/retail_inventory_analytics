import mysql.connector
from getpass import getpass

DB_HOST = "localhost"
DB_PORT = 3306
DB_USER = "root"
DB_NAME = "retail_inventory_db"


def get_connection():
    password = getpass(f"MySQL password for user '{DB_USER}': ")
    try:
        conn = mysql.connector.connect(
            host=DB_HOST,
            port=DB_PORT,
            user=DB_USER,
            password=password,
            database=DB_NAME,
        )
        return conn
    except mysql.connector.Error as e:
        print("Error connecting to database:", e)
        return None
