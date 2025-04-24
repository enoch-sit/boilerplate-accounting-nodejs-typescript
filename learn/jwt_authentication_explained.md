# Understanding JWT Authentication

This guide explains how JSON Web Tokens (JWT) are implemented in the Simple Accounting authentication system.

## What is JWT?

JWT (JSON Web Token) is an open standard ([RFC 7519](https://tools.ietf.org/html/rfc7519)) for securely transmitting information between parties as a JSON object. The information can be verified because it's digitally signed.

## JWT Structure

A JWT consists of three parts separated by dots (`.`):
1. **Header** - Contains the type of token and the signing algorithm
2. **Payload** - Contains the claims (data)
3. **Signature** - Used to verify the message wasn't changed

Example: `xxxxx.yyyyy.zzzzz`

## How JWTs Are Used in This System

In our Simple Accounting application:

1. **Token Creation**: When a user logs in, the server:
   - Verifies user credentials
   - Creates a JWT containing user ID and role information
   - Signs it with a secret key
   - Sets it as an HTTP-only cookie

2. **Authentication**: For subsequent requests:
   - The browser automatically sends the cookie with requests
   - Our middleware extracts and verifies the JWT
   - If valid, the user is authenticated

3. **Authorization**: Based on the user's role stored in the JWT payload, access to certain routes is permitted or denied.

## JWT Implementation

### Token Generation (Login)

```typescript
// Simplified version of what happens in auth.service.ts
import jwt from 'jsonwebtoken';

function generateToken(userId: string, role: string): string {
  return jwt.sign(
    { userId, role },
    process.env.JWT_SECRET,
    { expiresIn: '24h' }
  );
}

// When user logs in:
const token = generateToken(user._id, user.role);
res.cookie('auth_token', token, {
  httpOnly: true,
  secure: process.env.NODE_ENV === 'production',
  maxAge: 24 * 60 * 60 * 1000 // 24 hours
});
```

### Token Verification (Middleware)

```typescript
// Simplified version of auth.middleware.ts
import jwt from 'jsonwebtoken';

const authenticate = (req, res, next) => {
  const token = req.cookies.auth_token;
  
  if (!token) {
    return res.status(401).json({ message: 'Authentication required' });
  }
  
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch (error) {
    return res.status(401).json({ message: 'Invalid token' });
  }
};
```

## Security Considerations

Our JWT implementation includes several security best practices:

1. **HTTP-Only Cookies**: Prevents JavaScript from accessing tokens, protecting against XSS attacks
2. **Short Expiration**: Tokens expire after 24 hours
3. **Secure Flag**: In production, cookies are only sent over HTTPS
4. **Proper Signing**: Using a strong secret key for signing tokens
5. **Minimal Payload**: Only essential information is stored in tokens

## Common JWT Pitfalls to Avoid

1. **Storing Sensitive Data**: Never store sensitive information in a JWT payload as it can be decoded
2. **Weak Secrets**: Always use a strong, random secret for signing
3. **Missing Expiration**: Tokens should always have an expiration time
4. **Client-Side Storage**: Avoid storing JWTs in localStorage (we use HTTP-only cookies)
5. **No Revocation Strategy**: Have a plan for handling token revocation (this system uses a token blacklist)

## Debugging JWT Issues

If you're having issues with JWT authentication:

1. Check that cookies are being properly set and sent
2. Verify that `JWT_SECRET` in the environment matches what was used to create the token
3. Ensure tokens haven't expired
4. Check for HTTP vs HTTPS issues with the secure cookie flag

## JWT vs Session Authentication

| Feature | JWT | Traditional Sessions |
|---------|-----|----------------------|
| Storage | Client-side (token) | Server-side (session ID) |
| Scalability | Better for microservices | Requires shared session storage |
| Stateless | Yes | No |
| Revocation | More complex | Simple |
| Payload Size | Larger | Smaller |

Our system uses JWT for its scalability and stateless nature, while mitigating common security concerns.

## Resources for Learning More

- [JWT.io](https://jwt.io/) - Interactive JWT debugger and documentation
- [OWASP JWT Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_for_Java_Cheat_Sheet.html)
- [RFC 7519](https://tools.ietf.org/html/rfc7519) - JWT specification