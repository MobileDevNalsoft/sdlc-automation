// Proves the form actually VALIDATES and SUBMITS at runtime — compiling only
// proved the zod<->RHF types line up, which is a different claim.
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import { EntityForm } from './EntityForm';

describe('EntityForm', () => {
  it('blocks submit and reports messages when required fields are empty', async () => {
    const user = userEvent.setup();
    const onSubmit = vi.fn();
    render(<EntityForm onSubmit={onSubmit} />);

    await user.click(screen.getByRole('button', { name: /save/i }));

    expect(await screen.findByText('Name is required')).toBeInTheDocument();
    expect(onSubmit).not.toHaveBeenCalled();
  });

  it('rejects a malformed email', async () => {
    const user = userEvent.setup();
    const onSubmit = vi.fn();
    render(<EntityForm onSubmit={onSubmit} />);

    await user.type(screen.getByLabelText('Email'), 'not-an-email');
    await user.click(screen.getByRole('button', { name: /save/i }));

    expect(await screen.findByText('Enter a valid email address')).toBeInTheDocument();
    expect(onSubmit).not.toHaveBeenCalled();
  });

  it('submits trimmed values with defaults resolved', async () => {
    const user = userEvent.setup();
    const onSubmit = vi.fn();
    render(<EntityForm onSubmit={onSubmit} />);

    // Trailing spaces on the email are the autofill/paste case schema.ts trims.
    await user.type(screen.getByLabelText('Name'), 'Ada Lovelace');
    await user.type(screen.getByLabelText('Email'), '  ada@example.com  ');
    await user.type(screen.getByLabelText('Company'), 'Analytical Engines');
    await user.click(screen.getByRole('button', { name: /save/i }));

    await waitFor(() => {
      expect(onSubmit).toHaveBeenCalledTimes(1);
    });

    expect(onSubmit.mock.calls[0]?.[0]).toMatchObject({
      name: 'Ada Lovelace',
      email: 'ada@example.com',
      company: 'Analytical Engines',
      // The whole point of the input/output split: absent on the way in,
      // guaranteed present on the way out.
      subscribed: true,
    });
  });
});
