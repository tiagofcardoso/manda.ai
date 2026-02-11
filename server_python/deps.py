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
    Validates that the current user has 'admin' or 'super_admin' role.
    Also fetches their establishment_id context.
    Super Admins can access any establishment if they set their establishment_id.
    Returns: tuple (user, establishment_id)
    """
    try:
        user_id = user.user.id
        # Check profile for role AND establishment (Source of Truth)
        res = supabase.table('profiles').select('role, establishment_id').eq('id', user_id).single().execute()
        
        # Accept both 'admin' and 'super_admin'
        if not res.data or res.data.get('role') not in ['admin', 'super_admin']:
             raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Admin privileges required"
            )
        
        establishment_id = res.data.get('establishment_id')
        
        # Return both user and establishment_id as a tuple
        return (user, establishment_id)
    except Exception as e:
        print(f"RBAC Error: {e}")
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

def get_current_driver(user = Depends(get_current_user)):
    """
    Validates that the current user has 'driver' role.
    Also fetches their establishment_id context.
    """
    try:
        user_id = user.user.id
        res = supabase.table('profiles').select('role, establishment_id').eq('id', user_id).single().execute()
        
        if not res.data or res.data.get('role') != 'driver':
             raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Driver privileges required"
            )
            
        user.establishment_id = res.data.get('establishment_id')
        return user
    except Exception as e:
        print(f"RBAC Error: {e}")
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

def get_current_super_admin(user = Depends(get_current_user)):
    """
    Validates that the current user has 'super_admin' role.
    Super Admins don't need establishment_id context because they see ALL.
    """
    try:
        user_id = user.user.id
        res = supabase.table('profiles').select('role').eq('id', user_id).single().execute()
        
        if not res.data or res.data.get('role') != 'super_admin':
             raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Super Admin privileges required"
            )
        return user
    except Exception as e:
        print(f"RBAC Error: {e}")
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")
