#
# TimeLogger is a utility class that keeps track of time that parts of code
# take to execute and prints them lazily.
#
# Class usage example:
#
# ```
# $t = [TimeLogger]::new()
# $t.Push("t")
#     $t.Push("t0")
#     $t.Pop()
#     $t.Push("t1")
#         $t.Push("t11")
#         $t.Pop()
#         $t.Push("t12")
#         $t.Pop()
#     $t.Pop()
#     $t.Push("t2")
#     $t.Pop()
#     $t.Measure("ttt1", { echo "test123" })
#     $t.LogAndMeasure("ttt2", { echo "test456" })
# $t.Pop()
# $t.Push("tx")
#     $t.Push("Should be closed automatically")
# $t.Done()
# ```
#
# console output:
#
# ```
# test123
# ttt2
# test456
# =======================================================

#  Time measurement results:

#      - [00:00:00.1036883]: Total
#                - [00:00:00.0560581]: t
#                          - [00:00:00.0089936]: t0
#                          - [00:00:00.0019979]: t1
#                                    - [00:00:00]: t11
#                                    - [00:00:00]: t12
#                          - [00:00:00.0009994]: t2
#                          - [00:00:00.0014296]: ttt1
#                          - [00:00:00]: ttt2
#                - [00:00:00.0156298]: tx
#                          - [00:00:00.0156298]: Should be closed automatically
# =======================================================
# ```

class TimeMeasurement {
    [string] $Name
    [DateTime] $Start
    [DateTime] $End
    [System.Collections.ArrayList] $Children

    TimeMeasurement ([string] $Name) {
        $this.Name = $Name
        $this.Children = New-Object System.Collections.ArrayList
    }

    [TimeSpan] GetResult() {
        return ($this.End - $this.Start)
    }

    Print([int] $IndentLevel) {
        $msg = ""
        1..($IndentLevel) | ForEach-Object{ $msg += " " }
        $msg += "- [" + ($this.GetResult()) + "]: " + $this.Name
        Write-Host $msg

        ForEach($Child in $this.Children) {
            $Child.Print($IndentLevel + 10)
        }
    }
}

class TimeLogger {
    [int] $CurrentIndentLevel
    [System.Collections.Stack] $Stack
    [TimeMeasurement] $Root

    TimeLogger () {
        $this.Root = [TimeMeasurement]::new("Total")
        $this.Root.Start = Get-Date
        $this.Stack = New-Object System.Collections.Stack
        $this.Stack.Push($this.Root)
        $this.CurrentIndentLevel = 0
    }

    LogAndPush([string] $msg) {
        Write-Host $msg
        $this.Push($msg)
    }

    Push([string] $msg) {
        $tm = [TimeMeasurement]::new($msg)
        $tm.Start = Get-Date
        $top = $this.Stack.Peek()
        $top.Children.Add($tm)
        $this.Stack.Push($tm)
    }

    Pop() {
        $tm = $this.Stack.Pop()
        $tm.End = Get-Date
    }

    LogAndMeasure([string] $msg, [scriptblock] $block) {
        Write-Host $msg
        $this.Measure($msg, $block)
    }

    Measure([string] $msg, [scriptblock] $block) {
        $this.Push($msg)
        $sb = [scriptblock]::Create($block)
        & $sb | ForEach-Object { Write-Host "$_" }
        $this.Pop()
    }

    Done() {
        Write-Host "=======================================================`n"
        Write-Host " Time measurement results: `n"
        while($this.Root -ne $this.Stack.Peek()) {
            $this.Pop()
        }
        $this.Root.End = Get-Date
        $this.Root.Print(5)
        Write-Host "=======================================================`n"
    }
}
