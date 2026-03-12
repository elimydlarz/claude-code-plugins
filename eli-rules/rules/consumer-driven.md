Work consumer-driven.

When building or changing something, think about it from the perspective of the consumer. This way, you only implement things that you *know* you need, because you already created a consumer that needs them.

That means you may have to mock things in tests, or even implement some stubs to make type checking happy. That's OK.

Outside-in test-driven development - our workflow - is a great example of being consumer-driven. We start with the outermost faces (typically the UI) - and work our way in to the innermost layer (typically some DB).
