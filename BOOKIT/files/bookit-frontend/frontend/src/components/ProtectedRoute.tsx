import { Navigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

interface ProtectedRouteProps {
  children: React.ReactNode;
  requireRole?: 'admin' | 'customer';
}

/**
 * Client-side route protection is a UX convenience, NOT a real security
 * boundary - a user could disable JS and hit the API directly. The actual
 * security lives server-side: the gateway's requireAuth middleware and
 * availability-service's requireRole check. This component just avoids
 * flashing protected UI at people who aren't logged in.
 */
export function ProtectedRoute({ children, requireRole }: ProtectedRouteProps) {
  const { user, loading } = useAuth();

  if (loading) {
    return <div className="loading-screen">Loading...</div>;
  }

  if (!user) {
    return <Navigate to="/login" replace />;
  }

  if (requireRole && user.role !== requireRole) {
    return <Navigate to="/" replace />;
  }

  return <>{children}</>;
}
