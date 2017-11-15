function Noexcept([string] $msg, [scriptblock] $block) {
    $sb = [scriptblock]::Create($block)
    return Invoke-Command -ScriptBlock {
        $ErrorActionPreference = "SilentlyContinue"
        $sb = [scriptblock]::Create($block)
        & $sb
        return $LASTEXITCODE
    }
}
