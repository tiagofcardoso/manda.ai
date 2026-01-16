from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from database import supabase

security = HTTPBearer()

def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """
    Validates the Bearer token using Supabase Auth.
    Returns the user data if valid, raises 401 otherwise.
    """
    token = credentials.credentials
    
    if not supabase:
         raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database connection unavailable"
        )

    try:
        # supabase.auth.get_user(token) validates the JWT
        user = supabase.auth.get_user(token)
        if not user:
             raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid authentication credentials",
                headers={"WWW-Authenticate": "Bearer"},
            )
        return user
    except Exception as e:
        print(f"Auth Error: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

def get_current_admin(user = Depends(get_current_user)):
    """
    Validates that the current user has 'admin' role.
    """
    try:
        user_id = user.user.id
        # Check profile for role (Source of Truth)
        res = supabase.table('profiles').select('role').eq('id', user_id).single().execute()
        
        if not res.data or res.data.get('role') != 'admin':
             raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Admin privileges required"
            )
        return user
    except Exception as e:
        print(f"RBAC Error: {e}")
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

def get_current_driver(user = Depends(get_current_user)):
    """
    Validates that the current user has 'driver' role.
    """
    try:
        user_id = user.user.id
        res = supabase.table('profiles').select('role').eq('id', user_id).single().execute()
        
        if not res.data or res.data.get('role') != 'driver':
             raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Driver privileges required"
            )
        return user
    except Exception as e:
        print(f"RBAC Error: {e}")
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")
