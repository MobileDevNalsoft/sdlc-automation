// DESTINATION: src/features/auth/components/LoginPage.tsx
//
// PLACEHOLDER — react-sdlc:react-slice replaces this with the real auth
// feature. It wires useSignIn with dummy data so RequireAuth/RequireAnonymous's
// pre-mount redirect is demonstrable before a real auth slice exists, and so
// router.tsx's default route table compiles on a bare bootstrap.
import { useSignIn } from '@/shared/store/auth-store';
import { Button } from '@/shared/ui/Button';

export function LoginPage(): React.ReactElement {
  const signIn = useSignIn();

  return (
    <div className="p-8">
      <h1 className="text-xl font-semibold text-fg">Log in</h1>
      <Button
        className="mt-4"
        onClick={() =>
          signIn({ id: '1', email: 'demo@example.com', displayName: 'Demo User' }, 'demo-token')
        }
      >
        Log in as demo user
      </Button>
    </div>
  );
}
