# Azure Authentication Troubleshooting Guide

## Common Azure Login Errors and Solutions

### Error: "Not all values are present. Ensure 'client-id' and 'tenant-id' are supplied"

This error occurs when the `AZURE_CREDENTIALS` secret is missing or incorrectly formatted.

#### Solution 1: Verify Secret Format

The `AZURE_CREDENTIALS` secret must be a JSON object with this exact format:

```json
{
  "clientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "clientSecret": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "subscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```

**Important**: The JSON must be minified (single line) when added to GitHub Secrets.

#### Solution 2: Check Organization-Level Secrets

If using organization-level secrets:

1. Go to your GitHub Organization Settings
2. Navigate to Secrets and variables > Actions
3. Verify `AZURE_CREDENTIALS` exists
4. Check that the repository has access to the secret:
   - Click on the secret
   - Under "Repository access", ensure your repo is selected
   - Or select "All repositories" if appropriate

#### Solution 3: Create New Service Principal

Create a fresh service principal with proper permissions:

```bash
# Login to Azure CLI
az login

# Set your subscription
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Create service principal and capture output
az ad sp create-for-rbac \
  --name "github-actions-sp" \
  --role Contributor \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID \
  --sdk-auth
```

Copy the JSON output and add it as the `AZURE_CREDENTIALS` secret.

### Error: "Login failed with Error: Using auth-type: SERVICE_PRINCIPAL"

This indicates the service principal authentication is failing.

#### Possible Causes:

1. **Expired Client Secret**: Service principal secrets expire
2. **Insufficient Permissions**: Service principal lacks required roles
3. **Wrong Subscription**: Service principal created for different subscription

#### Solutions:

**Reset Client Secret:**
```bash
# Get the service principal ID
az ad sp list --display-name "github-actions-sp" --query "[0].appId" -o tsv

# Reset the secret
az ad sp credential reset --name "APP_ID_FROM_ABOVE" --sdk-auth
```

**Verify Permissions:**
```bash
# Check role assignments
az role assignment list --assignee "APP_ID" --all

# Should show "Contributor" role for your subscription
```

### Error: "The subscription 'xxx' could not be found"

#### Solutions:

1. **Verify Subscription ID:**
   ```bash
   az account list --output table
   ```

2. **Ensure Service Principal has access:**
   ```bash
   az ad sp show --id "CLIENT_ID" --query appId
   ```

### GitHub Actions Specific Issues

#### Using Repository Secrets vs Organization Secrets

**Repository Secret:**
- Set in: Settings > Secrets and variables > Actions
- Access: `${{ secrets.AZURE_CREDENTIALS }}`
- Scope: Only this repository

**Organization Secret:**
- Set in: Organization Settings > Secrets and variables > Actions
- Access: Same syntax `${{ secrets.AZURE_CREDENTIALS }}`
- Scope: Selected repositories or all
- **Note**: Repository must be granted access

#### Environment-Specific Secrets

If using environments in GitHub Actions:

```yaml
jobs:
  deploy:
    environment: production  # This line is important
    steps:
      - uses: azure/login@v2
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
```

Ensure the secret exists in the environment settings.

### Debugging Steps

1. **Add Debug Output** (temporary, remove after testing):
   ```yaml
   - name: Debug Azure Login
     run: |
       echo "Secret exists: ${{ secrets.AZURE_CREDENTIALS != '' }}"
       echo "Secret length: ${{ length(secrets.AZURE_CREDENTIALS) }}"
   ```

2. **Test Locally:**
   ```bash
   # Save credentials to file
   echo '{your-json}' > azure-creds.json
   
   # Test login
   az login --service-principal \
     --username CLIENT_ID \
     --password CLIENT_SECRET \
     --tenant TENANT_ID
   ```

3. **Verify JSON Format:**
   ```bash
   # Validate JSON
   echo '${{ secrets.AZURE_CREDENTIALS }}' | jq .
   ```

### Prevention Tips

1. **Action Version Compatibility:**
   ```yaml
   - uses: azure/login@v1  # v2 has breaking changes for service principal auth
   ```
   
   **Note**: While v2 is the latest version, it has breaking changes for service principal authentication with the `creds` format. Use v1 for compatibility with the traditional JSON credentials format.

2. **Set Explicit Permissions:**
   ```yaml
   permissions:
     id-token: write
     contents: read
   ```

3. **Use OIDC Authentication** (Recommended for enhanced security):
   ```yaml
   - uses: azure/login@v2
     with:
       client-id: ${{ secrets.AZURE_CLIENT_ID }}
       tenant-id: ${{ secrets.AZURE_TENANT_ID }}
       subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
   ```

### Quick Checklist

- [ ] JSON is valid and minified
- [ ] All 4 required fields present (clientId, clientSecret, subscriptionId, tenantId)
- [ ] Service principal has Contributor role
- [ ] Secret is accessible to the repository
- [ ] Using azure/login@v2 (not v1)
- [ ] No extra whitespace or newlines in secret
- [ ] Subscription ID matches your Azure account
- [ ] Service principal secret hasn't expired

### Still Having Issues?

1. Check Azure AD logs for authentication failures
2. Enable GitHub Actions debug logging:
   - Add secret: `ACTIONS_RUNNER_DEBUG` = `true`
   - Add secret: `ACTIONS_STEP_DEBUG` = `true`
3. Contact GitHub Support with workflow run URL