# KBS Authorization Policy
# This policy controls which resources can be accessed based on attestation claims

package policy

# Default deny all requests
default allow = false
input_tcb := input["submods"]["cpu0"]["ear.veraison.annotated-evidence"]
path := split(data["resource-path"], "/")

#allow {
#    input["submods"]["cpu0"]["ear.status"] == "affirming"
#}
