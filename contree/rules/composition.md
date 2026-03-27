We strictly prefer composition over inheritance in this project:
1. **No `extends`**: Do not create class hierarchies (except for standard library extensions like `Error`).
2. **Use Hooks**: Share logic using React Hooks or functional utilities.
3. **Use Component Composition**: Pass functionality as props or children.

### ❌ BAD: Inheritance
```typescript
class BaseButton extends React.Component {
  track() { console.log('click'); }
}

class SubmitButton extends BaseButton {
  render() {
    return <button onClick={this.track}>Submit</button>;
  }
}
```

### ✅ GOOD: Composition (Hooks)
```typescript
const useTracking = () => {
    return () => console.log('click');
};
const SubmitButton = () => {
    const track = useTracking();
    return <button onClick={track}>Submit</button>;
};
```

### ✅ GOOD: Composition (Components)
```typescript
const wrapper = (Component) => (props) => (
    <div className="wrapper">
        <Component {...props} />
    </div>
);
```
