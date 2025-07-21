# ReadtheDocs Setup Instructions

This guide will help you connect your AutoDecrypt project to ReadtheDocs for automated documentation hosting.

## Prerequisites

- ✅ GitHub repository created and pushed: `https://github.com/bryankemp/autodecrypt`
- ✅ Documentation files in `docs/` directory
- ✅ `.readthedocs.yaml` configuration file
- ✅ `docs/requirements.txt` with Sphinx dependencies

## Step 1: Create ReadtheDocs Account

1. Go to [https://readthedocs.org](https://readthedocs.org)
2. Click "Sign up" 
3. Choose "Sign up with GitHub" (recommended)
4. Authorize ReadtheDocs to access your GitHub account

## Step 2: Import Your Project

1. After logging in, click "Import a Project"
2. You should see your GitHub repositories listed
3. Find "autodecrypt" in the list
4. Click the "+" button next to it to import

**Alternative Manual Import:**
If the repository doesn't appear automatically:
1. Click "Import Manually"
2. Fill in the details:
   - **Name**: `autodecrypt`
   - **Repository URL**: `https://github.com/bryankemp/autodecrypt`
   - **Repository Type**: Git
   - **Default Branch**: `main`

## Step 3: Configure Project Settings

### Basic Settings
1. Go to your project admin page
2. Navigate to "Settings" → "Basic Settings"
3. Verify these settings:
   - **Name**: AutoDecrypt
   - **Repository URL**: `https://github.com/bryankemp/autodecrypt`
   - **Default Branch**: `main`
   - **Default Version**: `latest`
   - **Programming Language**: Python (for Sphinx)

### Advanced Settings
1. Go to "Settings" → "Advanced Settings"
2. Configure these options:
   - **Default Version**: `latest`
   - **Privacy Level**: Public
   - **Analytics Code**: (leave blank unless you have Google Analytics)
   - **Single Version**: ❌ Unchecked
   - **Build Images**: `Ubuntu 22.04`
   - **Requirements File**: `docs/requirements.txt`
   - **Python Configuration File**: (leave blank - we use .readthedocs.yaml)
   - **Cancel Build on Pull Request**: ✅ Checked
   - **Build Pull Requests**: ✅ Checked

### Build Configuration
The project is already configured via `.readthedocs.yaml`. Verify it contains:

```yaml
version: 2

build:
  os: ubuntu-22.04
  tools:
    python: "3.11"
    
sphinx:
  configuration: docs/conf.py

python:
  install:
  - requirements: docs/requirements.txt
```

## Step 4: Trigger First Build

1. Go to "Builds" in your project dashboard
2. Click "Build Version" 
3. Select "latest" and click "Build"
4. Monitor the build progress

**Expected Build Process:**
1. Clone repository
2. Install Python 3.11
3. Install dependencies from `docs/requirements.txt`
4. Run Sphinx build
5. Publish documentation

## Step 5: Verify Documentation

Once the build completes successfully:

1. Click "View Docs" to see your live documentation
2. Your documentation should be available at:
   `https://autodecrypt.readthedocs.io/`

### Expected Pages
Your documentation should include:
- Home page with project overview
- Installation guide
- Usage instructions
- Configuration details
- Security information
- Troubleshooting guide
- API reference
- Examples

## Step 6: Configure Webhooks (Automatic)

ReadtheDocs should automatically configure webhooks with GitHub. This means:
- Documentation rebuilds automatically when you push to `main`
- Pull request builds are created for documentation changes

To verify webhooks:
1. Go to your GitHub repository settings
2. Click "Webhooks"
3. You should see a ReadtheDocs webhook

## Troubleshooting

### Common Build Issues

**"No module named 'myst_parser'"**
- Solution: Check `docs/requirements.txt` includes `myst-parser==2.0.0`

**"Configuration file not found"**
- Solution: Ensure `docs/conf.py` exists and is valid

**"Build failed during sphinx build"**
- Check the build log for specific errors
- Verify all documentation files exist and have correct syntax

**"Theme not found"**
- Solution: Ensure `sphinx-rtd-theme` is in `docs/requirements.txt`

### Build Log Access
1. Go to "Builds" in your project dashboard
2. Click on the build number to see detailed logs
3. Check for error messages in the log output

### Manual Rebuild
If you need to manually trigger a rebuild:
1. Go to "Builds"
2. Click "Build Version"
3. Select the version to rebuild

## Customization Options

### Custom Domain (Optional)
1. Go to "Admin" → "Domains"
2. Add your custom domain (e.g., `docs.yoursite.com`)
3. Configure DNS CNAME record

### PDF Downloads
PDF generation is enabled by default. Users can download PDF versions of your documentation.

### Search
Full-text search is automatically enabled for your documentation.

## Maintenance

### Regular Updates
- Documentation rebuilds automatically on every push to `main`
- Monitor builds for failures
- Update dependencies in `docs/requirements.txt` as needed

### Version Management
- ReadtheDocs automatically creates versions for Git tags
- Consider tagging releases for version-specific documentation

## Success Checklist

- ✅ Project imported successfully
- ✅ First build completed without errors
- ✅ Documentation accessible at readthedocs.io URL
- ✅ All documentation pages render correctly
- ✅ Navigation works properly
- ✅ Search functionality works
- ✅ Webhook configured for automatic builds

## Support

If you encounter issues:
1. Check ReadtheDocs documentation: https://docs.readthedocs.io/
2. Review build logs for specific error messages
3. Check the AutoDecrypt project documentation for updates

Your AutoDecrypt documentation should now be live at:
**https://autodecrypt.readthedocs.io/**
