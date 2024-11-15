This directory contains samples of services we don't have integrated yet.

main.bicep: Good sample of ACA high-level, creates log analytics, registry and ACA env. (ignore Cog and AI search).
container-app.bicep: Sample on how to create a single ACA app in the environment.
session-pool.bicep: Sample on how to create a Dynamic Session pool.
session-pool-role-assignment.bicep: Sample on how to assign executor role onm the Dynamic Session to the chat app (created via container-app.bicep).
afd.bicep: Sample on how to use private link with ACA. This is focused on AFD but can be used in combination with others.