<#
    参考代码：
        https://github.com/lzybkr/ShowPSAst
    功能：
        递归遍历PowerShell抽象语法树，并将每个节点的类型、内容及父节点存储至csv文件
    用例：
        输入：
            Get-AST "C:\Users\Desktop\test\1" "C:\Users\Desktop\test\2" 
        输出：
            先序遍历的csv文件
 #>

function Traverse-Ast
{
    [OutputType("System.Collections.ArrayList")]
    param(
        
        ## The object to examine
        [Parameter(ValueFromPipeline = $true)]
        $InputObject 
    )

    process
    {
        $currentList=New-Object -TypeName System.Collections.ArrayList
        Set-StrictMode -Version 3
        # This a helper function to recursively walk the tree
        # and add all children to the given node list.
        function AddChildNode($child, $nodeList)
        {
            # A function to add an object to the display tree
            function PopulateNode($object, $nodeList)
            {
                foreach ($child in $object.PSObject.Properties)
                {
                    # Skip the Parent node, it's not useful here
                    if ($child.Name -eq 'Parent') { continue }

                    $childObject = $child.Value
        
                    if ($null -eq $childObject) { continue }

                    # Recursively add only Ast nodes.
                    if ($childObject -is [System.Management.Automation.Language.Ast])
                    {
                        AddChildNode $childObject $nodeList
                        continue
                    }

                    # Several Ast properties are collections of Ast, add them all
                    # as children of the current node.
                    $collection = $childObject -as [System.Management.Automation.Language.Ast[]]
                    if ($collection -ne $null)
                    {
                        for ($i = 0; $i -lt $collection.Length; $i++)
                        {
                            AddChildNode ($collection[$i]) $nodeList
                        }
                        continue
                    }
                    if ($childObject.GetType().FullName -match 'ReadOnlyCollection.*Tuple`2.*Ast.*Ast')
                    {
                        for ($i = 0; $i -lt $childObject.Count; $i++)
                        {
                            AddChildNode ($childObject[$i].Item1) $nodeList
                            AddChildNode ($childObject[$i].Item2) $nodeList
                        }
                        continue
                    }
                }
            }

            # Create the new node to add with the node text of the item type and extent
            $childNode = [Windows.Forms.TreeNode]@{
                Text = $child.GetType().Name + (" [{0},{1})" -f $child.Extent.StartOffset,$child.Extent.EndOffset)
                Tag = $child
            }
            $node = @{
                type = $child.GetType().Name;
                content=$child.Extent.Text;
                parent=$child.parent
            }
            $null = $nodeList.Add($childNode)
            $null=$currentList.Add($node)
            # Recursively add the current nodes children
            PopulateNode $child $childNode.Nodes          
        }


        # Create the TreeView for the Ast
        $treeView = [Windows.Forms.TreeView]@{}
        # Create the root node for the Ast
        if ($InputObject -is [scriptblock])
        {
            $InputObject = $InputObject.Ast
        }
        elseif ($InputObject -is [System.Management.Automation.FunctionInfo] -or
                $InputObject -is [System.Management.Automation.ExternalScriptInfo])
        {
            $InputObject = $InputObject.ScriptBlock.Ast
        }
        elseif ($InputObject -isnot [System.Management.Automation.Language.Ast])
        {
            $text = [string]$InputObject
            if (Test-Path -LiteralPath $text)
            {
                $path = Resolve-Path $text
                $InputObject = [System.Management.Automation.Language.Parser]::ParseFile($path.ProviderPath, [ref]$null, [ref]$null)
            }
            else
            {
                $InputObject = [System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$null, [ref]$null)
            }
        } 
        AddChildNode $InputObject $treeView.Nodes
        return $currentList
    }
}


function Get-AST {
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $topPath
        ,[Parameter(Mandatory=$true)]
        [string]
        $outPath
        )
        if($null -eq $outPath){
            mkdir $outPath
        }
       
    foreach($file in Get-ChildItem -Path $topPath){
       

        $list= Traverse-Ast $file.FullName
        $json = [Ordered]@{}
        $name=$file.Name 
        for($i=0;$i -lt $list.Count;$i++){
            # 通过PSCustomObject对象，组织list内容，导出值csv文件
            $list.Get($i) | ForEach-Object{
                [PSCustomObject]@{
                nodeNo=($i+1);
                type = $_.type;
                parent=$_.parent;
                content=$_.content
                
            }} | Export-Csv -Path "$outPath\$name.csv" -Append
            
        }
    }
}
