function Noexcept([scriptblock] $block) {
    return Invoke-Command -ScriptBlock {
        $ErrorActionPreference = "SilentlyContinue"
        $sb = [scriptblock]::Create($block)
        & $sb 2>&1
        return $LASTEXITCODE
    }
}
