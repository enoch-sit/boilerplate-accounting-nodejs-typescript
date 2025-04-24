# Understanding CORS in Web Applications

This guide explains Cross-Origin Resource Sharing (CORS) and how it's configured in the Simple Accounting authentication system.

## What is CORS?

CORS (Cross-Origin Resource Sharing) is a security feature implemented by browsers that restricts web pages from making requests to a different domain than the one that served the original page.

In simpler terms, CORS prevents your web application running at one origin (domain, protocol, or port) from requesting resources from a different origin, unless the other origin explicitly allows it.

## Why CORS Matters

Without CORS, any website could make requests to any API, potentially accessing sensitive data. CORS helps protect users by ensuring that servers can control which origins can access their resources.

For example, if your front-end application runs at `http://localhost:5173` and your API server at `http://localhost:3000`, the browser will block requests between them unless CORS is properly configured.

## CORS Headers Explained

The key HTTP headers involved in CORS:

1. **Access-Control-Allow-Origin**: Specifies which origins can access the resource
2. **Access-Control-Allow-Credentials**: Indicates if the request can include credentials (cookies, authorization headers)
3. **Access-Control-Allow-Methods**: Specifies which HTTP methods are allowed
4. **Access-Control-Allow-Headers**: Lists which HTTP headers can be used

## Preflight Requests

For certain requests (non-simple requests), browsers send a "preflight" OPTIONS request before the actual request:

1. Browser sends OPTIONS request asking if the actual request is allowed
2. Server responds with CORS headers indicating what's allowed
3. If approved, browser sends the actual request

Common triggers for preflight:
- Using methods other than GET, POST, or HEAD
- Using content types other than application/x-www-form-urlencoded, multipart/form-data, or text/plain
- Including custom headers

## CORS Configuration in This Project

In our Simple Accounting application, CORS is configured in `app.ts` using the Express `cors` middleware:

```typescript
const corsOptions = {
  origin: process.env.CORS_ORIGIN || 'http://localhost:5173',
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
};
app.use(cors(corsOptions));
```

Key aspects of our configuration:
1. **Specific Origin**: We specify exactly which origin can access our API (from environment variable or default)
2. **Credentials Support**: We allow credentials to be included in requests
3. **Defined Methods**: We explicitly list which HTTP methods are allowed
4. **Allowed Headers**: We specify which headers can be sent in requests

## Client-Side Configuration

When making requests from your front-end application, you need to include credentials for cookies to be sent:

```javascript
// Using fetch API with credentials
fetch('http://localhost:3000/api/auth/login', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  },
  credentials: 'include', // This is important!
  body: JSON.stringify({
    email: 'user@example.com',
    password: 'password123'
  })
})
```

## Common CORS Issues and Solutions

### Problem: "No 'Access-Control-Allow-Origin' header"
**Solution**: Ensure the server includes this header with the correct origin

### Problem: "Response to preflight request doesn't pass access control check"
**Solution**: Make sure the server handles OPTIONS requests and sets the correct CORS headers

### Problem: "The value of the 'Access-Control-Allow-Origin' header must not be the wildcard '*' when the request's credentials mode is 'include'"
**Solution**: When using credentials, you must specify an exact origin, not '*'

### Problem: Cookies not being sent
**Solution**: Ensure your client includes `credentials: 'include'` and the server has `credentials: true`

## CORS Security Best Practices

1. **Be Specific**: Only allow access from trusted origins
2. **Minimum Permissions**: Only allow the necessary methods and headers
3. **Avoid Wildcards with Credentials**: Never use `*` for origins when credentials are enabled
4. **Environment-Specific**: Use different CORS configurations for development and production

## Testing CORS Configuration

You can test if your CORS configuration is working properly by:

1. Opening your browser's developer tools
2. Making a cross-origin request
3. Checking the Network tab for the request and response headers

If you see CORS errors, check both your server configuration and client request setup.

## Resources for Learning More

- [MDN CORS Guide](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS)
- [Express cors middleware](https://expressjs.com/en/resources/middleware/cors.html)
- [CORS Visualization](https://jakearchibald.com/2021/cors/)