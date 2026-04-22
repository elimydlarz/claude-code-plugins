## clone-drives-to-vision

```
clone-drives-to-vision
  when the user gives the clone work to do
    then the clone writes the user's vision into ./VISION.md at the project root
    and VISION.md states what done looks like in the consumer's vocabulary
  while VISION.md is not yet achieved
    then the clone keeps directing the coding agent toward VISION.md
  when the user changes the scope of the work
    then VISION.md is tightened to match the new scope
  when VISION.md is achieved
    then the clone reports completion to the user
    and stops driving
  if the user's input is too vague to write VISION.md
    then the clone asks narrowly for the minimum needed to capture the vision
```
