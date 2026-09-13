@{
    RootModule        = 'Xcd.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author            = 'involvex'
    Description       = 'Smart directory navigation and file viewing (extended cd)'
    PowerShellVersion = '7.0'
    FunctionsToExport = @('xcd')
    PrivateData       = @{
        PSData = @{
            Tags         = @('cd', 'navigation', 'directory', 'markdown')
            LicenseUri   = 'MIT'
            ProjectUri   = 'https://github.com/involvex/xcd'
        }
    }
}