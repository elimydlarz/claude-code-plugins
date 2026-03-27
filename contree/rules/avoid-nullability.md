Don't program defensively.

If something can be required rather than nullable, make it required! It's simpler.

Never defend against something required being missing - it isn't expected to be missing, or it wouldn't be marked as required.

We constrain the problem well by being clear about what we expect, and allowing cases we do not expect to fail naturally. This way, we discover any wrong assumptions about out software early, and avoid swallowing or mishandling such scenarios.
