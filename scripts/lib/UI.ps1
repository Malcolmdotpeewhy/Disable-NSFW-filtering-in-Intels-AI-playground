<#
.SYNOPSIS
    WPF UI for STARK.
.DESCRIPTION
    Embeds XAML to provide a modern interface.
#>

function Show-StarkUI {
    param(
        [string]$BasePath,
        [scriptblock]$PatchAction,
        [scriptblock]$RestoreAction
    )

    try {
        Add-Type -AssemblyName PresentationFramework
        Add-Type -AssemblyName System.Windows.Forms
    } catch {
        Write-Warning "UI Components not supported in this environment (Linux/Core). UI Disabled."
        return
    }

    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="STARK: NSFW Disabler 🦾" Height="450" Width="600"
        WindowStartupLocation="CenterScreen" ResizeMode="CanMinimize"
        Background="#1E1E1E">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#333"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="Padding" Value="10,5"/>
            <Setter Property="Margin" Value="5"/>
            <Setter Property="BorderThickness" Value="0"/>
        </Style>
        <Style TargetType="TextBlock">
            <Setter Property="Foreground" Value="#DDD"/>
            <Setter Property="FontFamily" Value="Segoe UI"/>
        </Style>
    </Window.Resources>

    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Header -->
        <StackPanel Grid.Row="0" Margin="0,0,0,15">
            <TextBlock Text="AI Playground: NSFW Disabler" FontSize="20" FontWeight="Bold" Foreground="#00BFFF"/>
            <TextBlock Text="Powered by STARK Transformation Agent" FontSize="12" Foreground="#888"/>
        </StackPanel>

        <!-- Status / Log Area -->
        <Border Grid.Row="1" Background="#111" CornerRadius="5" Padding="10">
            <ScrollViewer Name="LogScroller" VerticalScrollBarVisibility="Auto">
                <TextBlock Name="LogOutput" TextWrapping="Wrap" FontFamily="Consolas" FontSize="12" Foreground="#0F0"/>
            </ScrollViewer>
        </Border>

        <!-- Actions -->
        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,15,0,0">
            <Button Name="BtnPatch" Content="DISABLE FILTERS (Apply Patch)" Width="200" Background="#2E8B57"/>
            <Button Name="BtnRestore" Content="RESTORE ORIGINAL" Width="150" Background="#CD5C5C"/>
            <Button Name="BtnExit" Content="EXIT" Width="80"/>
        </StackPanel>
    </Grid>
</Window>
"@

    try {
        $reader = (New-Object System.Xml.XmlNodeReader ([xml]$xaml))
        $window = [Windows.Markup.XamlReader]::Load($reader)
    } catch {
        Write-Warning "Failed to load WPF XAML."
        Write-Error $_
        return
    }

    # Controls
    $logOutput = $window.FindName("LogOutput")
    $scroller = $window.FindName("LogScroller")
    $btnPatch = $window.FindName("BtnPatch")
    $btnRestore = $window.FindName("BtnRestore")
    $btnExit = $window.FindName("BtnExit")

    # Connect Logger
    Register-StatusCallback -Callback {
        param($e)
        $window.Dispatcher.Invoke([Action]{
            $logOutput.Text += $e.Message + "`n"
            $scroller.ScrollToEnd()
        })
    }

    # Events
    $btnPatch.Add_Click({
        $btnPatch.IsEnabled = $false
        $btnRestore.IsEnabled = $false

        # Run in separate runspace or just process events?
        # For simplicity in this single-threaded app, we rely on UI refresh or just blocking briefly.
        # To keep UI responsive, we force update.
        [System.Windows.Forms.Application]::DoEvents()

        & $PatchAction

        $btnPatch.IsEnabled = $true
        $btnRestore.IsEnabled = $true
    })

    $btnRestore.Add_Click({
        $btnPatch.IsEnabled = $false
        $btnRestore.IsEnabled = $false
        [System.Windows.Forms.Application]::DoEvents()

        & $RestoreAction

        $btnPatch.IsEnabled = $true
        $btnRestore.IsEnabled = $true
    })

    $btnExit.Add_Click({
        $window.Close()
    })

    $window.ShowDialog() | Out-Null
}
