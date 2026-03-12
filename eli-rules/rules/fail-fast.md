When there is no reason to expect some scenario, we prefer not to handle it explicitly and simply let the system fail when this scenario does occur.

This is because:
- We don't want to create complexity handling cases that may never arise
- In the event that such unexpected cases do arise, we would rather they fail fast and loud than be mishandled or hidden

*Do not* propose tests or implemenation for unexpected scenarios, where a failure will be easily detected anyway. We do not want to engage in defensive programming. For example, if a type indicates that a field is required, you should not test to see what happens if it is undefined. In such cases, we can simply allow the system to fail, and then I'll be back here asking you to update the typeps and/or plan for whatever scenario created the failure. We never try to solve those problems in advance, because most of them never happen. It's better to focus both tests and implementation on the core logic of the system.

Exceptions:
- When such an unexpected case would have dire consequences or be impossible to detect, we can handle it explicitly (e.g. throwing an exception early rather than allowing dire consequences or non-detection)
