# KBS Authorization Policy
# This policy controls which resources can be accessed based on attestation claims
#
# For production use, customize this policy to match your security requirements.
# See: https://github.com/confidential-containers/trustee/blob/main/docs/policy.md

package policy

# Default deny all requests
default allow = false

# Path to check claims in the attestation token
# Adjust based on your attestation token structure
tcb = input.tcb

# Allow all requests (DEVELOPMENT ONLY - replace with proper rules)
# Remove or comment out this rule in production
allow {
    true
}

# Example: Allow only if the workload is from a trusted TEE
# allow {
#     tcb.tee == "snp"
#     tcb.tcb_status == "UpToDate"
# }

# Example: Allow access to specific resources based on claims
# allow {
#     input.resource.path == ["default", "secrets", "db-password"]
#     tcb.workload_id == "trusted-workload-hash"
# }

# Example: Deny if platform is not up to date
# deny {
#     tcb.tcb_status != "UpToDate"
# }
