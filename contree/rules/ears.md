Test trees use EARS (Easy Approach to Requirements Syntax) to choose the right keyword for each requirement. Match the pattern to the requirement's nature — don't force everything into `when/then`.

Six patterns, mapped to test tree syntax:

Ubiquitous — always true, no condition:
```
then <outcome>
```

State-driven — active while a condition holds:
```
while <precondition>
  then <outcome>
```

Event-driven — response to a trigger:
```
when <trigger>
  then <outcome>
```

Optional feature — applies only when a feature is present:
```
where <feature>
  then <outcome>
```

Unwanted behaviour — response to error or undesired situation:
```
if <condition>
  then <outcome>
```

Complex — state + event combined:
```
while <precondition>
  when <trigger>
    then <outcome>
```

Causal nesting — when a trigger can only occur as a consequence of a prior outcome, nest it under that outcome:
```
when <trigger>
  then <outcome>
    when <consequence of outcome>
      then <next outcome>
```
A `when` that depends on a preceding `then` is not a sibling — it is a child. If "refresh fails" can only happen because "refresh was attempted", nest it under the `then` that attempts the refresh.

Choose the pattern that fits. A system constraint is ubiquitous. A precondition that must hold is state-driven. A discrete trigger is event-driven. An error case is unwanted behaviour. A feature flag is optional. Combine when needed. Nest when one behaviour depends on another's outcome.
