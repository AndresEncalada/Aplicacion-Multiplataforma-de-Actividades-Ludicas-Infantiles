"""
Módulo de seguridad y autenticación para profesores:
- Hashing criptográfico PBKDF2-SHA256 compatible con el formato auth_user de Django.
- Emisión y verificación de JSON Web Tokens (JWT - RFC 7519) con HMAC-SHA256 (HS256).
- Dependencias OAuth2 Bearer para proteger los endpoints de FastAPI.
"""
import base64
import hashlib
import hmac
import json
import os
import secrets
import time
from typing import Any, Dict, Optional

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

# Clave secreta para firmar JWT (configurable por variable de entorno)
JWT_SECRET_KEY = os.environ.get(
    "FELPUDO_JWT_SECRET",
    "felpudo_secret_key_tesis_educacion_inicial_2026_hs256_secure"
)
JWT_ALGORITHM = "HS256"
JWT_EXPIRATION_SECONDS = int(os.environ.get("FELPUDO_JWT_EXP_SECONDS", 60 * 60 * 12))  # 12 horas
PBKDF2_ITERATIONS = 260000

security_bearer = HTTPBearer(auto_error=False)


# =====================================================================
# 1. HASHING DE CONTRASEÑAS (PBKDF2-SHA256 compatible con Django)
# =====================================================================

def hashear_password(password: str, salt: Optional[str] = None, iterations: int = PBKDF2_ITERATIONS) -> str:
    """
    Genera un hash seguro con formato compatible con Django:
    pbkdf2_sha256$<iteraciones>$<salt>$<hash_base64>
    """
    if not salt:
        salt = secrets.token_hex(8)
    dk = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt.encode("utf-8"),
        iterations
    )
    hash_b64 = base64.b64encode(dk).decode("ascii").strip()
    return f"pbkdf2_sha256${iterations}${salt}${hash_b64}"


def verificar_password(password_plano: str, password_hash: str) -> bool:
    """
    Verifica una contraseña contra su hash PBKDF2-SHA256 en tiempo constante.
    """
    if not password_plano or not password_hash:
        return False
    try:
        partes = password_hash.split("$")
        if len(partes) != 4 or partes[0] != "pbkdf2_sha256":
            return False
        iterations = int(partes[1])
        salt = partes[2]
        hash_esperado = partes[3]
        calculado = hashear_password(password_plano, salt=salt, iterations=iterations)
        return hmac.compare_digest(calculado, password_hash)
    except Exception:
        return False


# =====================================================================
# 2. IMPLEMENTACIÓN ESTÁNDAR JWT (RFC 7519 - HS256)
# =====================================================================

def _b64url_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _b64url_decode(data: str) -> bytes:
    rem = len(data) % 4
    if rem > 0:
        data += "=" * (4 - rem)
    return base64.urlsafe_b64decode(data.encode("ascii"))


def crear_jwt_token(profesor: Dict[str, Any], expires_delta: int = JWT_EXPIRATION_SECONDS) -> str:
    """
    Crea un token JWT firmado con HS256 para el profesor autenticado.
    """
    ahora = int(time.time())
    header = {"alg": JWT_ALGORITHM, "typ": "JWT"}
    payload = {
        "sub": str(profesor["id"]),
        "profesor_id": int(profesor["id"]),
        "username": profesor.get("username", ""),
        "name": f"{profesor.get('first_name', '')} {profesor.get('last_name', '')}".strip(),
        "email": profesor.get("email", ""),
        "role": "profesor",
        "iat": ahora,
        "exp": ahora + expires_delta,
    }

    header_b64 = _b64url_encode(json.dumps(header, separators=(",", ":")).encode("utf-8"))
    payload_b64 = _b64url_encode(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
    mensaje = f"{header_b64}.{payload_b64}".encode("ascii")

    firma = hmac.new(JWT_SECRET_KEY.encode("utf-8"), mensaje, hashlib.sha256).digest()
    firma_b64 = _b64url_encode(firma)

    return f"{header_b64}.{payload_b64}.{firma_b64}"


def decodificar_jwt_token(token: str) -> Dict[str, Any]:
    """
    Valida la firma HS256 y la fecha de expiración del token JWT.
    Lanza HTTPException 401 si el token es inválido o expiró.
    """
    try:
        partes = token.split(".")
        if len(partes) != 3:
            raise ValueError("Formato de token JWT inválido")

        header_b64, payload_b64, firma_recibida_b64 = partes
        mensaje = f"{header_b64}.{payload_b64}".encode("ascii")

        firma_esperada = hmac.new(JWT_SECRET_KEY.encode("utf-8"), mensaje, hashlib.sha256).digest()
        firma_esperada_b64 = _b64url_encode(firma_esperada)

        if not hmac.compare_digest(firma_recibida_b64, firma_esperada_b64):
            raise ValueError("Firma de token JWT inválida")

        payload = json.loads(_b64url_decode(payload_b64).decode("utf-8"))
        ahora = int(time.time())
        if payload.get("exp", 0) < ahora:
            raise ValueError("El token de sesión ha expirado")

        return payload
    except ValueError as err:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(err),
            headers={"WWW-Authenticate": "Bearer"},
        )
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciales de autenticación inválidas. Por favor inicie sesión nuevamente.",
            headers={"WWW-Authenticate": "Bearer"},
        )


async def obtener_profesor_actual(
    request: Request,
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security_bearer),
) -> Dict[str, Any]:
    """
    Dependencia OAuth2 Bearer para rutas protegidas.
    Acepta token por cabecera 'Authorization: Bearer <jwt>' o parámetro query '?token=<jwt>'.
    """
    token = None
    if credentials and credentials.credentials:
        token = credentials.credentials
    else:
        token = request.query_params.get("token")

    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="No autenticado. Inicie sesión con su cuenta de profesor.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return decodificar_jwt_token(token)
