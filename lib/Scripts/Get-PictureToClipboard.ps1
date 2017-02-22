function Get-PictureToClipboard {
    param($Picture)
    [Reflection.Assembly]::LoadWithPartialName('System.Drawing')
    [Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')

    $file = get-item($Picture)
    $img = [System.Drawing.Image]::Fromfile($file)
    [System.Windows.Forms.Clipboard]::SetImage($img)
}