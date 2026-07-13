<powershell>


# Rename computer

Rename-Computer `
-NewName "DC01" `
-Force


# Install Active Directory Domain Services

Install-WindowsFeature `
-Name AD-Domain-Services `
-IncludeManagementTools


# Install DNS

Install-WindowsFeature `
-Name DNS `
-IncludeManagementTools



Restart-Computer -Force


</powershell>