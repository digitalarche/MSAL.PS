<#
.SYNOPSIS
    Acquire a token using MSAL.NET library.
.DESCRIPTION
    This command will acquire OAuth tokens for both public and confidential clients. Public clients authentication can be interactive, integrated Windows auth, or silent (aka refresh token authentication).
.EXAMPLE
    PS C:\>Get-MsalToken -ClientId '00000000-0000-0000-0000-000000000000' -Scope 'https://graph.microsoft.com/User.Read','https://graph.microsoft.com/Files.ReadWrite'
    Get AccessToken (with MS Graph permissions User.Read and Files.ReadWrite) and IdToken using client id from application registration (public client).
.EXAMPLE
    PS C:\>Get-MsalToken -ClientId '00000000-0000-0000-0000-000000000000' -TenantId '00000000-0000-0000-0000-000000000000' -Interactive -Scope 'https://graph.microsoft.com/User.Read' -LoginHint user@domain.com
    Force interactive authentication to get AccessToken (with MS Graph permissions User.Read) and IdToken for specific Azure AD tenant and UPN using client id from application registration (public client).
.EXAMPLE
    PS C:\>Get-MsalToken -ClientId '00000000-0000-0000-0000-000000000000' -ClientSecret (ConvertTo-SecureString 'SuperSecretString' -AsPlainText -Force) -TenantId '00000000-0000-0000-0000-000000000000' -Scope 'https://graph.microsoft.com/.default'
    Get AccessToken (with MS Graph permissions .Default) and IdToken for specific Azure AD tenant using client id and secret from application registration (confidential client).
.EXAMPLE
    PS C:\>$ClientCertificate = Get-Item Cert:\CurrentUser\My\0000000000000000000000000000000000000000
    PS C:\>$MsalClientApplication = Get-MsalClientApplication -ClientId '00000000-0000-0000-0000-000000000000' -ClientCertificate $ClientCertificate -TenantId '00000000-0000-0000-0000-000000000000'
    PS C:\>$MsalClientApplication | Get-MsalToken -Scope 'https://graph.microsoft.com/.default'
    Pipe in confidential client options object to get a confidential client application using a client certificate and target a specific tenant.
#>
function Get-MsalToken {
    [CmdletBinding(DefaultParameterSetName = 'PublicClient')]
    [OutputType([Microsoft.Identity.Client.AuthenticationResult])]
    param
    (
        # Identifier of the client requesting the token.
        [Parameter(Mandatory = $true, ParameterSetName = 'PublicClient', Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $true, ParameterSetName = 'PublicClient-Interactive', Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $true, ParameterSetName = 'PublicClient-IntegratedWindowsAuth', Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $true, ParameterSetName = 'PublicClient-Silent', Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $true, ParameterSetName = 'PublicClient-UsernamePassword', Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $true, ParameterSetName = 'PublicClient-DeviceCode', Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $true, ParameterSetName = 'ConfidentialClientSecret', Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $true, ParameterSetName = 'ConfidentialClientSecret-AuthorizationCode', Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $true, ParameterSetName = 'ConfidentialClientSecret-OnBehalfOf', Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $true, ParameterSetName = 'ConfidentialClientCertificate', Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $true, ParameterSetName = 'ConfidentialClientCertificate-AuthorizationCode', Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $true, ParameterSetName = 'ConfidentialClientCertificate-OnBehalfOf', Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string] $ClientId,

        # Secure secret of the client requesting the token.
        [Parameter(Mandatory = $true, ParameterSetName = 'ConfidentialClientSecret', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $true, ParameterSetName = 'ConfidentialClientSecret-AuthorizationCode', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $true, ParameterSetName = 'ConfidentialClientSecret-OnBehalfOf', ValueFromPipelineByPropertyName = $true)]
        [securestring] $ClientSecret,

        # Client assertion certificate of the client requesting the token.
        [Parameter(Mandatory = $true, ParameterSetName = 'ConfidentialClientCertificate', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $true, ParameterSetName = 'ConfidentialClientCertificate-AuthorizationCode', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $true, ParameterSetName = 'ConfidentialClientCertificate-OnBehalfOf', ValueFromPipelineByPropertyName = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2] $ClientCertificate,

        # Specifies if the x5c claim (public key of the certificate) should be sent to the STS.
        [Parameter(Mandatory = $false, ParameterSetName = 'ConfidentialClient-InputObject')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ConfidentialClientCertificate-AuthorizationCode')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ConfidentialClientCertificate-OnBehalfOf')]
        [switch] $SendX5C,

        # The authorization code received from service authorization endpoint.
        [Parameter(Mandatory = $false, ParameterSetName = 'ConfidentialClient-InputObject')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ConfidentialClientSecret-AuthorizationCode')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ConfidentialClientCertificate-AuthorizationCode')]
        [string] $AuthorizationCode,

        # Assertion representing the user.
        [Parameter(Mandatory = $false, ParameterSetName = 'ConfidentialClient-InputObject', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $true, ParameterSetName = 'ConfidentialClientSecret-OnBehalfOf', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $true, ParameterSetName = 'ConfidentialClientCertificate-OnBehalfOf', ValueFromPipelineByPropertyName = $true)]
        [string] $UserAssertion,

        # Type of the assertion representing the user.
        [Parameter(Mandatory = $false, ParameterSetName = 'ConfidentialClient-InputObject', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $false, ParameterSetName = 'ConfidentialClientSecret-OnBehalfOf', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $false, ParameterSetName = 'ConfidentialClientCertificate-OnBehalfOf', ValueFromPipelineByPropertyName = $true)]
        [string] $UserAssertionType,

        # Address to return to upon receiving a response from the authority.
        [Parameter(Mandatory = $false, ParameterSetName = 'PublicClient', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $false, ParameterSetName = 'PublicClient-Interactive', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $false, ParameterSetName = 'PublicClient-IntegratedWindowsAuth', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $false, ParameterSetName = 'PublicClient-Silent', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $false, ParameterSetName = 'PublicClient-UsernamePassword', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $false, ParameterSetName = 'PublicClient-DeviceCode', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $false, ParameterSetName = 'ConfidentialClientSecret', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $false, ParameterSetName = 'ConfidentialClientSecret-AuthorizationCode', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $false, ParameterSetName = 'ConfidentialClientSecret-OnBehalfOf', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $false, ParameterSetName = 'ConfidentialClientCertificate', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $false, ParameterSetName = 'ConfidentialClientCertificate-AuthorizationCode', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $false, ParameterSetName = 'ConfidentialClientCertificate-OnBehalfOf', ValueFromPipelineByPropertyName = $true)]
        [uri] $RedirectUri,

        # Instance of Azure Cloud
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [Microsoft.Identity.Client.AzureCloudInstance] $AzureCloudInstance,

        # Tenant identifier of the authority to issue token. It can also contain the value "consumers" or "organizations".
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [string] $TenantId,

        # Address of the authority to issue token.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [uri] $Authority,

        # Public client application
        [Parameter(Mandatory = $true, ParameterSetName = 'PublicClient-InputObject', Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Microsoft.Identity.Client.IPublicClientApplication] $PublicClientApplication,

        # Confidential client application
        [Parameter(Mandatory = $true, ParameterSetName = 'ConfidentialClient-InputObject', Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Microsoft.Identity.Client.IConfidentialClientApplication] $ConfidentialClientApplication,

        # Interactive request to acquire a token for the specified scopes.
        [Parameter(Mandatory = $true, ParameterSetName = 'PublicClient-Interactive')]
        [Parameter(Mandatory = $false, ParameterSetName = 'PublicClient-InputObject')]
        [switch] $Interactive,

        # Non-interactive request to acquire a security token for the signed-in user in Windows, via Integrated Windows Authentication.
        [Parameter(Mandatory = $true, ParameterSetName = 'PublicClient-IntegratedWindowsAuth')]
        [Parameter(Mandatory = $false, ParameterSetName = 'PublicClient-InputObject')]
        [switch] $IntegratedWindowsAuth,

        # Attempts to acquire an access token from the user token cache.
        [Parameter(Mandatory = $true, ParameterSetName = 'PublicClient-Silent')]
        [Parameter(Mandatory = $false, ParameterSetName = 'PublicClient-InputObject')]
        [switch] $Silent,

        # Acquires a security token on a device without a Web browser, by letting the user authenticate on another device.
        [Parameter(Mandatory = $true, ParameterSetName = 'PublicClient-DeviceCode')]
        [Parameter(Mandatory = $false, ParameterSetName = 'PublicClient-Interactive')]
        [Parameter(Mandatory = $false, ParameterSetName = 'PublicClient-InputObject')]
        [switch] $DeviceCode,

        # Array of scopes requested for resource
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [string[]] $Scopes = 'https://graph.microsoft.com/.default',

        # Array of scopes for which a developer can request consent upfront.
        [Parameter(Mandatory = $false, ParameterSetName = 'PublicClient', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $false, ParameterSetName = 'PublicClient-Interactive', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $false, ParameterSetName = 'PublicClient-InputObject', ValueFromPipelineByPropertyName = $true)]
        [string[]] $ExtraScopesToConsent,

        # Identifier of the user. Generally a UPN.
        [Parameter(Mandatory = $false, ParameterSetName = 'PublicClient', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $false, ParameterSetName = 'PublicClient-Interactive', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $false, ParameterSetName = 'PublicClient-IntegratedWindowsAuth', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $false, ParameterSetName = 'PublicClient-Silent', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $false, ParameterSetName = 'PublicClient-InputObject', ValueFromPipelineByPropertyName = $true)]
        [string] $LoginHint,

        # Specifies the what the interactive experience is for the user. To force an interactive authentication, use the -Interactive switch.
        [Parameter(Mandatory = $false, ParameterSetName = 'PublicClient', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $false, ParameterSetName = 'PublicClient-Interactive', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $false, ParameterSetName = 'PublicClient-InputObject', ValueFromPipelineByPropertyName = $true)]
        [ArgumentCompleter( {
                param ( $commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters )
                [Microsoft.Identity.Client.Prompt].DeclaredFields | Where-Object { $_.IsPublic -eq $true -and $_.IsStatic -eq $true -and $_.Name -like "$wordToComplete*" } | Select-Object -ExpandProperty Name
            })]
        [string] $Prompt,

        # Identifier of the user with associated password.
        [Parameter(Mandatory = $true, ParameterSetName = 'PublicClient-UsernamePassword', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $false, ParameterSetName = 'PublicClient-InputObject', ValueFromPipelineByPropertyName = $true)]
        [pscredential]
        [System.Management.Automation.Credential()]
        $UserCredential,

        # Correlation id to be used in the authentication request.
        [Parameter(Mandatory = $false)]
        [guid] $CorrelationId,

        # This parameter will be appended as is to the query string in the HTTP authentication request to the authority.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [hashtable] $ExtraQueryParameters,

        # Ignore any access token in the user token cache and attempt to acquire new access token using the refresh token for the account if one is available.
        [Parameter(Mandatory = $false, ParameterSetName = 'PublicClient')]
        [Parameter(Mandatory = $false, ParameterSetName = 'PublicClient-Silent')]
        [Parameter(Mandatory = $false, ParameterSetName = 'PublicClient-InputObject')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ConfidentialClientSecret')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ConfidentialClientCertificate')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ConfidentialClient-InputObject')]
        [switch] $ForceRefresh,

        # Specifies if the public client application should used an embedded web browser or the system default browser
        [Parameter(Mandatory = $false, ParameterSetName = 'PublicClient', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $false, ParameterSetName = 'PublicClient-Interactive', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $false, ParameterSetName = 'PublicClient-InputObject', ValueFromPipelineByPropertyName = $true)]
        [switch] $UseEmbeddedWebView
    )

    begin {
        function CheckForMissingScopes([Microsoft.Identity.Client.AuthenticationResult]$AuthenticationResult, [string[]]$Scopes) {
            foreach ($Scope in $Scopes) {
                if ($AuthenticationResult.Scopes -notcontains $Scope) { return $true }
            }
            return $false
        }

    }

    process {
        switch -Wildcard ($PSCmdlet.ParameterSetName) {
            "PublicClient-InputObject" {
                [Microsoft.Identity.Client.IPublicClientApplication] $ClientApplication = $PublicClientApplication
                break
            }
            "ConfidentialClient-InputObject" {
                [Microsoft.Identity.Client.IConfidentialClientApplication] $ClientApplication = $ConfidentialClientApplication
                break
            }
            "PublicClient*" {
                $paramSelectMsalClientApplication = Select-PsBoundParameters $PSBoundParameters -CommandName Select-MsalClientApplication -CommandParameterSets "PublicClient"
                [Microsoft.Identity.Client.IPublicClientApplication] $PublicClientApplication = Select-MsalClientApplication @paramSelectMsalClientApplication
                [Microsoft.Identity.Client.IPublicClientApplication] $ClientApplication = $PublicClientApplication
                break
            }
            "ConfidentialClientSecret*" {
                $paramSelectMsalClientApplication = Select-PsBoundParameters $PSBoundParameters -CommandName Select-MsalClientApplication -CommandParameterSets "ConfidentialClientSecret"
                [Microsoft.Identity.Client.IConfidentialClientApplication] $ConfidentialClientApplication = Select-MsalClientApplication @paramSelectMsalClientApplication
                [Microsoft.Identity.Client.IConfidentialClientApplication] $ClientApplication = $ConfidentialClientApplication
                break
            }
            "ConfidentialClientCertificate*" {
                $paramSelectMsalClientApplication = Select-PsBoundParameters $PSBoundParameters -CommandName Select-MsalClientApplication -CommandParameterSets "ConfidentialClientCertificate"
                [Microsoft.Identity.Client.IConfidentialClientApplication] $ConfidentialClientApplication = Select-MsalClientApplication @paramSelectMsalClientApplication
                [Microsoft.Identity.Client.IConfidentialClientApplication] $ClientApplication = $ConfidentialClientApplication
                break
            }
        }

        [Microsoft.Identity.Client.AuthenticationResult] $AuthenticationResult = $null
        switch -Wildcard ($PSCmdlet.ParameterSetName) {
            "PublicClient*" {
                if ($PSBoundParameters.ContainsKey("UserCredential") -and $UserCredential) {
                    $AquireTokenParameters = $PublicClientApplication.AcquireTokenByUsernamePassword($Scopes, $UserCredential.UserName, $UserCredential.Password)
                }
                elseif ($PSBoundParameters.ContainsKey("DeviceCode") -and $DeviceCode) {
                    $AquireTokenParameters = $PublicClientApplication.AcquireTokenWithDeviceCode($Scopes, [DeviceCodeHelper]::GetDeviceCodeResultCallback())
                }
                elseif ($PSBoundParameters.ContainsKey("Interactive") -and $Interactive) {
                    $AquireTokenParameters = $PublicClientApplication.AcquireTokenInteractive($Scopes)
                    [IntPtr] $ParentWindow = [System.Diagnostics.Process]::GetCurrentProcess().MainWindowHandle
                    if ($ParentWindow) { [void] $AquireTokenParameters.WithParentActivityOrWindow($ParentWindow) }
                    #if ($Account) { [void] $AquireTokenParameters.WithAccount($Account) }
                    if ($extraScopesToConsent) { [void] $AquireTokenParameters.WithExtraScopesToConsent($extraScopesToConsent) }
                    if ($LoginHint) { [void] $AquireTokenParameters.WithLoginHint($LoginHint) }
                    if ($Prompt) { [void] $AquireTokenParameters.WithPrompt([Microsoft.Identity.Client.Prompt]::$Prompt) }
                    if ($PSBoundParameters.ContainsKey('UseEmbeddedWebView')) { [void] $AquireTokenParameters.WithUseEmbeddedWebView($UseEmbeddedWebView) }
                }
                elseif ($PSBoundParameters.ContainsKey("IntegratedWindowsAuth") -and $IntegratedWindowsAuth) {
                    $AquireTokenParameters = $PublicClientApplication.AcquireTokenByIntegratedWindowsAuth($Scopes)
                    if ($LoginHint) { [void] $AquireTokenParameters.WithUsername($LoginHint) }
                }
                elseif ($PSBoundParameters.ContainsKey("Silent") -and $Silent) {
                    if ($LoginHint) {
                        $AquireTokenParameters = $PublicClientApplication.AcquireTokenSilent($Scopes, $LoginHint)
                    }
                    else {
                        [Microsoft.Identity.Client.IAccount] $Account = $PublicClientApplication.GetAccountsAsync().GetAwaiter().GetResult() | Select-Object -First 1
                        $AquireTokenParameters = $PublicClientApplication.AcquireTokenSilent($Scopes, $Account)
                    }
                    if ($PSBoundParameters.ContainsKey('ForceRefresh')) { [void] $AquireTokenParameters.WithForceRefresh($ForceRefresh) }
                }
                else {
                    $paramGetMsalToken = Select-PsBoundParameters -NamedParameter $PSBoundParameters -CommandName 'Get-MsalToken' -CommandParameterSet 'PublicClient-InputObject' -ExcludeParameters 'PublicClientApplication'
                    ## Try Silent Authentication
                    Write-Verbose ('Attempting Silent Authentication to Application with ClientId [{0}]' -f $ClientApplication.ClientId)
                    try {
                        $AuthenticationResult = Get-MsalToken -Silent -PublicClientApplication $PublicClientApplication @paramGetMsalToken
                        ## Check for requested scopes
                        if (CheckForMissingScopes $AuthenticationResult $Scopes) {
                            $AuthenticationResult = Get-MsalToken -Interactive -PublicClientApplication $PublicClientApplication @paramGetMsalToken
                        }
                    }
                    catch [Microsoft.Identity.Client.MsalUiRequiredException] {
                        Write-Debug ('{0}: {1}' -f $_.Exception.GetType().Name, $_.Exception.Message)
                        ## Try Integrated Windows Authentication
                        Write-Verbose ('Attempting Integrated Windows Authentication to Application with ClientId [{0}]' -f $ClientApplication.ClientId)
                        try {
                            $AuthenticationResult = Get-MsalToken -IntegratedWindowsAuth -PublicClientApplication $PublicClientApplication @paramGetMsalToken
                            ## Check for requested scopes
                            if (CheckForMissingScopes $AuthenticationResult $Scopes) {
                                $AuthenticationResult = Get-MsalToken -Interactive -PublicClientApplication $PublicClientApplication @paramGetMsalToken
                            }
                        }
                        catch {
                            Write-Debug ('{0}: {1}' -f $_.Exception.GetType().Name, $_.Exception.Message)
                            ## Revert to Interactive Authentication
                            Write-Verbose ('Attempting Interactive Authentication to Application with ClientId [{0}]' -f $ClientApplication.ClientId)
                            $AuthenticationResult = Get-MsalToken -Interactive -PublicClientApplication $PublicClientApplication @paramGetMsalToken
                        }
                    }
                    break
                }
            }
            "ConfidentialClient*" {
                if ($PSBoundParameters.ContainsKey("AuthorizationCode")) {
                    $AquireTokenParameters = $ConfidentialClientApplication.AcquireTokenByAuthorizationCode($Scopes, $AuthorizationCode)
                }
                elseif ($PSBoundParameters.ContainsKey("UserAssertion")) {
                    if ($UserAssertionType) { [Microsoft.Identity.Client.UserAssertion] $UserAssertionObj = New-Object Microsoft.Identity.Client.UserAssertion -ArgumentList $UserAssertion, $UserAssertionType }
                    else { [Microsoft.Identity.Client.UserAssertion] $UserAssertionObj = New-Object Microsoft.Identity.Client.UserAssertion -ArgumentList $UserAssertion }
                    $AquireTokenParameters = $ConfidentialClientApplication.AcquireTokenOnBehalfOf($Scopes, $UserAssertionObj)
                }
                else {
                    $AquireTokenParameters = $ConfidentialClientApplication.AcquireTokenForClient($Scopes)
                    if ($SendX5C) { [void] $AquireTokenParameters.WithSendX5C($SendX5C) }
                    if ($PSBoundParameters.ContainsKey('ForceRefresh')) { [void] $AquireTokenParameters.WithForceRefresh($ForceRefresh) }
                }
            }
            "*" {
                if ($AzureCloudInstance -and $TenantId) { [void] $AquireTokenParameters.WithAuthority($AzureCloudInstance, $TenantId) }
                elseif ($AzureCloudInstance) { [void] $AquireTokenParameters.WithAuthority($AzureCloudInstance, 'common') }
                elseif ($TenantId) { [void] $AquireTokenParameters.WithAuthority(('https://{0}' -f $ClientApplication.AppConfig.AuthorityInfo.Host), $TenantId) }
                if ($Authority) { [void] $AquireTokenParameters.WithAuthority($Authority.AbsoluteUri) }
                if ($CorrelationId) { [void] $AquireTokenParameters.WithCorrelationId($CorrelationId) }
                if ($ExtraQueryParameters) { [void] $AquireTokenParameters.WithExtraQueryParameters((ConvertTo-Dictionary $ExtraQueryParameters -KeyType ([string]) -ValueType ([string]))) }
                Write-Debug ('Aquiring Token for Application with ClientId [{0}]' -f $ClientApplication.ClientId)
                try {
                    $AuthenticationResult = $AquireTokenParameters.ExecuteAsync().GetAwaiter().GetResult()
                }
                catch {
                    Write-Error -Exception $_.Exception.InnerException -Category ([System.Management.Automation.ErrorCategory]::AuthenticationError) -CategoryActivity $MyInvocation.MyCommand -ErrorId 'GetMsalTokenFailureAuthenticationError' -TargetObject $AquireTokenParameters -ErrorAction Stop
                }
                break
            }
        }

        return $AuthenticationResult
    }
}
