<#
 功能：递归遍历PowerShell抽象语法树，将每个节点存储于ArrayList对象
 
 #>

 $nodeList =New-Object -TypeName System.Collections.ArrayList


 Function Get-Node{
    # 输入脚本文件路径
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Path
    )
    $nodeList.RemoveRange(0,$nodeList.Count)
    $ast=Get-AST -filePath $Path
    TraverseAST -AST $ast
    foreach($node in $nodeList){
        Write-Host $node.GetType(),":",$node.Extent.Text,"`n"
    }
 }


 Function Get-AST{
    # 用OutputType设置返回值类型
    [OutputType("System.Management.Automation.Language.Ast")]
    param(
        # Parameter help description
        [Parameter(Mandatory=$true)]
        [string]
        $filePath
    )
    $token=@();
    $ast=[System.Management.Automation.Language.Parser]::ParseFile($filePath, [ref]$token, [ref]$null);
    return $ast
}

Function TraverseAST{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.Language.Ast]
        $AST
    )
    foreach ($node in $ast.PSObject.Properties)
    {
        if(($node.Name -ne "parent") -and ($null -ne $node.Value )){
            $childObject=$node.Value
            $collection = $childObject -as [System.Management.Automation.Language.Ast[]]   
            if($childObject -is [System.Management.Automation.Language.Ast]){
                # 每次add元素时总会返回当前的list容量，把它输出给$null
                $null=$nodeList.Add($childObject)
                TraverseAST($childObject)
               
            }# 处理多个ast
            elseif ($null -ne $collection){
                    for ($i = 0; $i -lt $collection.Length; $i++)
                    {
                        TraverseAST ($collection[$i])
                    }
                }# 处理if和switch字句
            elseif($childObject.GetType().FullName -match 'ReadOnlyCollection.*Tuple`2.*Ast.*Ast')
            {
                for ($i = 0; $i -lt $childObject.Count; $i++)
                {
                    TraverseAST ($childObject[$i].Item1)
                    TraverseAST ($childObject[$i].Item2)
                }
            }
        }
    }
}

Get-Node -Path  "C:\Users\19393\Desktop\test\2.ps1"