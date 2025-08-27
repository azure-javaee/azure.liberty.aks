From Copilot:


Good question. Short answer: AGIC enablement doesn’t always need to create a fresh role assignment, so runs can pass without the UAMI having User Access Administrator. Your failing run hit the branch where a new assignment was needed; the successful run likely reused an already-authorized Application Gateway or had different timing/identity conditions.

Here are the common reasons this flips between pass/fail:

- Existing role assignment: If the Application Gateway already has the required role assignment for the AGIC identity (from a prior run or manual setup), `az aks enable-addons` won’t need to add it, so Contributor permission suffices and the run passes.
- Subscription/identity context drift: Different workflow runs can land under different principals/subscriptions or resource groups (run_id-based names). If a run targets a new App Gateway resource (new RG) that doesn’t have the assignment yet, the call needs User Access Administrator and fails if missing.
- Timing/provisioning effects: When the addon’s identity or app gateway is very newly created, the role assignment step sometimes races with ARM propagation. A small delay or a later re-run can succeed without changing permissions.
- Default credential vs MSI path: In Azure Deployment Script sandboxes, `az` sometimes struggles to fetch tokens via MSI (“Failed to connect to MSI”). Older CLI versions (e.g., 2.33.x) are more prone to this, making transient failures more likely on some runs and not others.
- Cluster identity mode: If the cluster already used system-assigned MI and AGIC was previously enabled/partially configured, the later run may not try to reconfigure it, so no new RA is attempted.

Why your topic-branch run failed while main passed
- Both workflows use the same templates, but each run creates new resource names (RGs, appgw) via GUID suffixes. On main, that specific run may have operated in a context where:
  - appgw reuse occurred, or
  - the principal had Owner/User Access Admin on the subscription, or
  - no new RA was required due to prior state in that resource group.
- On your branch run, the flow attempted a fresh role assignment on a newly created app gateway in a new RG and hit the permission boundary plus MSI/CLI instability, hence the failure.

Why my change still matters
- It removes the non-determinism. Granting the deployment-script UAMI User Access Administrator at subscription scope ensures it can always create the role assignment when needed. Upgrading the `az` version in the AGIC step reduces the MSI flakiness.
- With these in place, both the “first-time” and “already-assigned” cases should succeed consistently.

Practical next steps
- Re-run the failing branch’s IT validation. If your GitHub Actions principal isn’t Owner or User Access Admin on the subscription, we’ll still need that assigned once so the UAMI role assignments can be created.
- If you want belt-and-suspenders reliability, I can add a small retry/wait in enableAgic.sh between enabling managed identity and running `az aks enable-addons` to reduce timing failures.

If you want, I can add the wait/retry hardening now and also script a quick mvn package to regenerate ARM from Bicep so your next run uses the patched templates.
