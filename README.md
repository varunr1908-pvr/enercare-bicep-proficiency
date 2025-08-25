# enercare-bicep-proficiency

# Enercare Bicep Proficiency Test

This repo contains my solution for the **Enercare Key Vault Proficiency Test**.  
It uses Bicep templates and GitHub Actions to deploy a Key Vault that meets all Enercare requirements.

---

## 📂 Structure

- `bicep/_Base.ProficiencyTest.bicep` → root entry template
- `bicep/kv.module.bicep` → Key Vault logic
- `bicep/naming.bicep` → naming convention reference
- `bicep/parameters/*.json` → environment params
- `.github/workflows/deploy.yaml` → GitHub Actions pipeline
