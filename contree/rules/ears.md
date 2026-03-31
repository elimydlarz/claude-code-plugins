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

Choose the pattern that fits. A system constraint is ubiquitous. A precondition that must hold is state-driven. A discrete trigger is event-driven. An error case is unwanted behaviour. A feature flag is optional. Combine when needed.
