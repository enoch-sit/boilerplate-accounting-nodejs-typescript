# Debugging Docker Architecture Compatibility with bcrypt

## Issue Summary

When attempting to use the auth service in a Docker container, the API was inaccessible with the error:

```
The underlying connection was closed: The connection was closed unexpectedly.
```

This issue was preventing access to all API endpoints, including the basic health endpoint at `http://localhost:3000/health`.

## Root Cause Analysis

The root cause was identified as an architecture incompatibility issue with the `bcrypt` native module in the Docker container. The specific error found in the container logs was:

```
Error: Error loading shared library /app/node_modules/bcrypt/lib/binding/napi-v3/bcrypt_lib.node: Exec format error
```

This "Exec format error" is typical when trying to run a binary compiled for one CPU architecture (like x86) on a different architecture (like ARM).

## Debugging Process

### 1. Initial Verification

- Checked Docker container status using `docker ps` - confirmed containers were running
- Attempted to access the API endpoint with curl and Invoke-RestMethod - confirmed connection issues
- Verified port mappings were correct in the docker-compose file

### 2. Examining Container Logs

- Reviewed logs from the auth-service-dev container using `docker logs auth-service-dev`
- Discovered the bcrypt native module loading error
- Identified it was a typical architecture mismatch issue

### 3. Initial Solution Attempts

- Added build dependencies (python3, make, g++) to the Dockerfile.dev to enable native module compilation
- Attempted to explicitly rebuild bcrypt after installation with:

  ```
  RUN npm rebuild bcrypt --build-from-source
  ```

- These attempts were unsuccessful, with the same error persisting

## Solution

After multiple troubleshooting attempts, we implemented a full solution by:

1. **Replacing bcrypt with bcryptjs**:
   - bcryptjs is a pure JavaScript implementation with no native modules
   - Installed it with: `npm install bcryptjs @types/bcryptjs --save`

2. **Updating the User Model**:
   - Changed the import from `import bcrypt from 'bcrypt'` to `import bcrypt from 'bcryptjs'`
   - The API remained identical so no other changes were needed to the model

3. **Simplifying the Dockerfile.dev**:
   - Kept build dependencies for potential other native modules
   - Removed the explicit bcrypt rebuild step as it was no longer needed

## Verification

After implementing the solution:

- Rebuilt Docker containers with `docker-compose -f docker-compose.dev.yml up -d --build`
- Successfully accessed the health endpoint with `curl http://localhost:3000/health`
- Received a proper 200 OK response with `{"status":"ok"}` payload

## Key Learnings

1. **Architecture Compatibility**:
   - Native Node.js modules built for one architecture may not work on another
   - This is increasingly important with mixed x86/ARM environments (e.g., M1/M2 Macs)

2. **Pure JavaScript Alternatives**:
   - When available, pure JavaScript implementations offer better cross-architecture compatibility
   - bcryptjs as a drop-in replacement for bcrypt solved our issue without code changes

3. **Docker Environment Analysis**:
   - Container logs are essential for troubleshooting
   - Understanding how native modules are compiled in Docker containers is important

## Prevention for Future Projects

1. **Prefer portable dependencies**:
   - Use pure JavaScript libraries when possible for better portability
   - When native modules are needed, ensure Docker configuration supports proper compilation

2. **Better error logging**:
   - Ensure application errors are properly propagated to logs
   - Add architectural compatibility checks during startup

3. **Documentation updates**:
   - Added this debug track document for future reference
   - Consider updating the Testing Guide with a section on architecture compatibility

## References

- [bcryptjs npm package](https://www.npmjs.com/package/bcryptjs)
- [Node.js Native Module issues in Docker](https://nodejs.org/api/addons.html)
- [Docker Multi-Architecture Support](https://docs.docker.com/build/building/multi-platform/)
