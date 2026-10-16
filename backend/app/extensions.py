from flask_bcrypt import Bcrypt
from flask_cors import CORS
from flask_jwt_extended import JWTManager
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()
jwt = JWTManager()
bcrypt = Bcrypt()
cors = CORS()
# Attempt limits (login, register, contact). Kept in memory: fine for one server process.
limiter = Limiter(key_func=get_remote_address, storage_uri="memory://")
