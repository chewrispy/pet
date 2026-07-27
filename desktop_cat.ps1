# ============================================
#  Desktop Cat v3 - 바탕화면 픽셀 고양이 위젯
#  실행: start_cat.bat 더블클릭
#  조작: 고양이 클릭 = 점프 / 우클릭 = 종료
# ============================================

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$script:rand = New-Object System.Random

# ---------- 픽셀아트 프레임 (PNG, base64 내장) ----------
function New-Frame([string]$b64) {
    $bytes = [Convert]::FromBase64String($b64)
    $ms = New-Object System.IO.MemoryStream(, $bytes)
    $img = New-Object System.Windows.Media.Imaging.BitmapImage
    $img.BeginInit()
    $img.StreamSource = $ms
    $img.CacheOption = 'OnLoad'
    $img.EndInit()
    $img.Freeze()
    return $img
}

$fWalk1 = New-Frame 'iVBORw0KGgoAAAANSUhEUgAAABgAAAAQCAYAAAAMJL+VAAAAxElEQVR4nGNgoBew1lb4j49PLmBC5nxd7P0f2WB0PjmABV1gbXwdA6/k2v+fnwczMDCsJctQmKOOXn3AyIQuySu5FoUmx/BdFdpwPooFZh0PsLJJNdyt4yrD0asPGDEsOFWhwMDAwMDw+XkwnE2J4QwMWOKAgQEzeIiJaGyGMzAwMKBwkMPvyZ3HDDIqsiiG4BPDZjgDA1oQIQN0g/CJ4TIcrwVP7jwmSowQoNgH+FyPAay1Ff7///UBnntJ5ZPkg1EAAwAiGnPLDRhZTgAAAABJRU5ErkJggg=='
$fWalk2 = New-Frame 'iVBORw0KGgoAAAANSUhEUgAAABgAAAAQCAYAAAAMJL+VAAAA10lEQVR4nGNgoBew1lb4j49PLmBC5nxd7P0f2WB0PjmABV1gbXwdA6/k2v+fnwczMDCsJctQmKOOXn3AyIQuySu5FoUmx/BdFdpwPooFZh0PsLJJNdyt4yrD0asPGDEsOFWhwMDAwMDw+XkwnE2J4QwMWOKAgQEzeIiJaGyGMzAwMKBwkMPvyZ3HDDIqsiiG4BPDZjgDA1oQIQN0g/CJ4TIcrwVP7jwmSowQoNgH+FyPFVhrK/z//+vDf2SaFHl0gDUVwQAjmwCGy45efcDIyCZAtbJq8AMA8A508tuRvVgAAAAASUVORK5CYII='
$fWalk3 = New-Frame 'iVBORw0KGgoAAAANSUhEUgAAABgAAAAQCAYAAAAMJL+VAAAAy0lEQVR4nGNgoBew1lb4j49PLmBC5nxd7P0f2WB0PjmABV1gbXwdA6/k2v+fnwczMDCspcRsBgYGNB8wMDAw8EquRaHJAdbaCnCfo1hg1vEAK5tUw3dVaMP5KBacqlBgYGBgYPj8PBjOJsdwt46rDEevPmBkYMASBwwMmMFDbESjG87AwMDAiKwA2XtP7jxmkFGRRTEAnxi6wTCAEckwgG4QPjFchuO14Mmdx0SJEQIU+wCf63ECa22F//9/fcCZiwnJIwOcPhgFMAAAvh1d8WiA4U4AAAAASUVORK5CYII='
$fSitA  = New-Frame 'iVBORw0KGgoAAAANSUhEUgAAABgAAAAQCAYAAAAMJL+VAAAAwUlEQVR4nGNgGChgra3wHx+fWMCET/LrYu//yAaj84kBLIQUrI2vY+CVXPv/8/NgBgaGtaSYzcDAQMAHDAwMDLySa1Foqlpg1vEAK5tqFpyqUGBgYGBg+Pw8GM6mqgUwgBw8uyq0SUpRBC14cucxBhuXJdbaChipjKAFMiqyWNnYDN9VoY0hTpYPGBiIDyqC+YCQD2CW7KrQZnDruMpw9OoDRpIswAeQgwSb4XiBtbbC//+/PmAtGvDJoQOikumgBgAnDFHEkKUPjgAAAABJRU5ErkJggg=='
$fSitB  = New-Frame 'iVBORw0KGgoAAAANSUhEUgAAABgAAAAQCAYAAAAMJL+VAAAAw0lEQVR4nGNgGChgra3wHx+fWMCET/LrYu//yAaj84kBLIQUrI2vY+CVXPv/8/NgBgaGtaSYzcDAQMAHDAwMDLySa1Foqlpg1vEAK5tqFpyqUGBgYGBg+Pw8GM6mqgUwgBw8uyq0SUpRBC14cucxBpsUSwhaIKMii5VNLCDLBwwMmL6w1lb4D8PI+gnmA0I+gBm4q0KbgYGBgcGt4yqKPEEL8AGYocgGH736gJEozdbaCv////qAtWjAJ4cOiEqmgxoAABmdTeyc0v4jAAAAAElFTkSuQmCC'

# 걸음 사이클: 벌림 -> 중간 -> 모음 -> 중간 (반복)
$walkCycle = @($fWalk1, $fWalk2, $fWalk3, $fWalk2)

# ---------- 창 설정 (투명, 항상 위, 작업표시줄에 안 뜸) ----------
$window = New-Object System.Windows.Window
$window.WindowStyle        = 'None'
$window.AllowsTransparency = $true
$window.Background         = [System.Windows.Media.Brushes]::Transparent
$window.Topmost            = $true
$window.ShowInTaskbar      = $false
$window.ShowActivated      = $false
$window.SizeToContent      = 'WidthAndHeight'

# ---------- 말풍선 + 고양이 ----------
$panel = New-Object System.Windows.Controls.StackPanel
$panel.Orientation = 'Vertical'

$bubbleText = New-Object System.Windows.Controls.TextBlock
$runMeow = New-Object System.Windows.Documents.Run('야옹~ ')
$runHeart = New-Object System.Windows.Documents.Run([string][char]0x2665)
$runHeart.Foreground = [System.Windows.Media.Brushes]::Crimson
[void]$bubbleText.Inlines.Add($runMeow)
[void]$bubbleText.Inlines.Add($runHeart)
$bubbleText.FontSize = 14

$bubble = New-Object System.Windows.Controls.Border
$bubble.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromArgb(235, 255, 255, 255))
$bubble.CornerRadius = New-Object System.Windows.CornerRadius(10)
$bubble.Padding = New-Object System.Windows.Thickness(9, 4, 9, 4)
$bubble.Margin = New-Object System.Windows.Thickness(0, 0, 0, 5)
$bubble.HorizontalAlignment = 'Center'
$bubble.Visibility = 'Hidden'   # Hidden = 자리는 차지 (창 높이 유지)
$bubble.Child = $bubbleText

$cat = New-Object System.Windows.Controls.Image
$cat.Source = $fWalk1
$cat.Width  = 96    # 원본 24px -> 4배 확대
$cat.Height = 64
$cat.HorizontalAlignment = 'Center'
[System.Windows.Media.RenderOptions]::SetBitmapScalingMode($cat, 'NearestNeighbor')  # 픽셀 또렷하게

$scale = New-Object System.Windows.Media.ScaleTransform(1, 1)
$cat.RenderTransform = $scale
$cat.RenderTransformOrigin = '0.5,0.5'

[void]$panel.Children.Add($bubble)
[void]$panel.Children.Add($cat)
$window.Content = $panel

# ---------- 상태 ----------
$script:wa          = [System.Windows.SystemParameters]::WorkArea  # 작업표시줄 제외 영역
$script:x           = [double]($script:wa.Left + $script:wa.Width / 2)
$script:groundY     = $script:wa.Bottom - 120
$script:dir         = -1        # -1 = 왼쪽, 1 = 오른쪽
$script:state       = 'walk'    # walk / idle
$script:stateTicks  = 100
$script:jumpTicks   = 0
$script:bubbleTicks = 0
$script:tick        = 0

$window.Left = $script:x
$window.Top  = $script:groundY

$window.Add_Loaded({
    $script:groundY = $script:wa.Bottom - $window.ActualHeight
    $window.Top = $script:groundY
})

# ---------- 애니메이션 루프 (30ms) ----------
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(30)
$timer.Add_Tick({
    $script:tick++

    if ($script:jumpTicks -gt 0) {
        # 점프 중: 사인 곡선으로 부드럽게
        $script:jumpTicks--
        $p = 1 - ($script:jumpTicks / 14.0)
        $offset = 45 * [math]::Sin([math]::PI * $p)
        $window.Top = $script:groundY - $offset
        $cat.Source = $fWalk1   # 다리 쫙 편 자세로 점프
    }
    else {
        # 걷기 / 앉기 상태 전환
        $script:stateTicks--
        if ($script:stateTicks -le 0) {
            if ($script:rand.NextDouble() -lt 0.65) {
                $script:state = 'walk'
                if ($script:rand.NextDouble() -lt 0.5) { $script:dir = -$script:dir }
                $script:stateTicks = $script:rand.Next(80, 260)
            }
            else {
                $script:state = 'idle'
                $script:stateTicks = $script:rand.Next(60, 180)
            }
        }

        if ($script:state -eq 'walk') {
            $script:x += 1.8 * $script:dir

            # 화면 끝에서 방향 전환
            if ($script:x -lt $script:wa.Left) { $script:x = $script:wa.Left; $script:dir = 1 }
            $maxX = $script:wa.Right - $window.ActualWidth
            if ($script:x -gt $maxX) { $script:x = $maxX; $script:dir = -1 }

            $window.Left = $script:x
            $window.Top  = $script:groundY   # 창은 흔들지 않음 - 다리가 움직임을 표현

            # 걸음 사이클: 4틱(120ms)마다 다음 단계 (벌림->중간->모음->중간)
            $step = [int]([math]::Floor($script:tick / 4)) % 4
            $cat.Source = $walkCycle[$step]

            # 진행 방향으로 몸 뒤집기 (기본 그림은 왼쪽을 봄)
            if ($script:dir -gt 0) { $scale.ScaleX = -1 } else { $scale.ScaleX = 1 }
        }
        else {
            # 앉아서 쉬기 + 가끔 꼬리 살랑 (약 1.2초마다 0.2초간)
            $window.Top = $script:groundY
            if (($script:tick % 40) -lt 7) { $cat.Source = $fSitB }
            else { $cat.Source = $fSitA }
        }
    }

    # 말풍선 타이머
    if ($script:bubbleTicks -gt 0) {
        $script:bubbleTicks--
        if ($script:bubbleTicks -eq 0) { $bubble.Visibility = 'Hidden' }
    }
})

# ---------- 인터랙션 ----------
$window.Add_MouseLeftButtonDown({
    if ($script:jumpTicks -le 0) { $script:jumpTicks = 14 }
    $bubble.Visibility = 'Visible'
    $script:bubbleTicks = 35
})

$window.Add_MouseRightButtonDown({
    $timer.Stop()
    $window.Close()
})

$timer.Start()
[void]$window.ShowDialog()
