# ============================================
#  Desktop Horse v4 - 바탕화면 픽셀 말 위젯
#  실행: start_horse.bat 더블클릭
#  행동: 질주 / 서기 / 풀뜯기 / 응가(바닥에 남음)
#  조작: 말 클릭 = 점프 / 말 우클릭 = 종료 / 응가 우클릭 = 치우기
# ============================================

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
Add-Type -AssemblyName System.Windows.Forms, System.Drawing   # 다중 모니터 정보 조회용

$script:rand = New-Object System.Random

# ---------- 다중 모니터 지원 ----------
# 배율이 섞인 다중 모니터에서는 좌표 왜곡이 모니터마다 달라서 단일 변환 계수가 어긋난다.
# 그래서 WPF 창 자신의 좌표 변환(PointToScreen/PointFromScreen)으로 매번 실측한다.
# 창이 실제 배치되는 좌표계와 같은 변환을 쓰므로 항상 자기 일관성이 보장된다.

function Get-GroundDip([double]$dipX) {
    # dipX(WPF 좌표) 지점이 속한 모니터의 작업영역 바닥을 WPF 좌표로 환산
    try {
        $localX = $dipX - $window.Left
        $sp = $window.PointToScreen((New-Object System.Windows.Point($localX, 0)))
        $scr = [System.Windows.Forms.Screen]::FromPoint((New-Object System.Drawing.Point([int]$sp.X, [int]$sp.Y)))
        $lp = $window.PointFromScreen((New-Object System.Windows.Point($sp.X, [double]$scr.WorkingArea.Bottom)))
        return $window.Top + $lp.Y
    }
    catch {
        # 변환 실패(창 로드 전 등) 시 기존 바닥값 유지
        return $script:groundY + $window.ActualHeight
    }
}

function Update-Screens {
    # 모든 모니터 작업영역을 WPF 좌표 x구간 목록으로 만들고(정렬+병합) 이동 가능 범위 갱신
    $ranges = @()
    foreach ($s in [System.Windows.Forms.Screen]::AllScreens) {
        $cy = [double](($s.WorkingArea.Top + $s.WorkingArea.Bottom) / 2)
        $pl = $window.PointFromScreen((New-Object System.Windows.Point([double]$s.WorkingArea.Left,  $cy)))
        $pr = $window.PointFromScreen((New-Object System.Windows.Point([double]$s.WorkingArea.Right, $cy)))
        $ranges += , @{ L = $window.Left + $pl.X; R = $window.Left + $pr.X }
    }
    $ranges = @($ranges | Sort-Object { $_.L })
    $merged = New-Object System.Collections.ArrayList
    foreach ($rg in $ranges) {
        if ($merged.Count -gt 0 -and $rg.L -le ($merged[$merged.Count - 1].R + 1)) {
            if ($rg.R -gt $merged[$merged.Count - 1].R) { $merged[$merged.Count - 1].R = $rg.R }
        }
        else { [void]$merged.Add(@{ L = $rg.L; R = $rg.R }) }
    }
    $script:xRanges = $merged
    $script:minX = $merged[0].L
    $script:maxX = $merged[$merged.Count - 1].R
}

function Get-RandomTargetX {
    # 실제 모니터 위에서만 목적지 선택 (모니터 사이 빈 공간 제외, 넓은 모니터일수록 자주)
    $hw = $window.ActualWidth
    $usable = @(); $total = 0.0
    foreach ($rg in $script:xRanges) {
        $span = ($rg.R - $rg.L) - $hw
        if ($span -gt 0) { $usable += , @{ L = $rg.L; Span = $span }; $total += $span }
    }
    if ($total -le 0) { return $script:x }
    $t = $script:rand.NextDouble() * $total
    foreach ($u in $usable) {
        if ($t -le $u.Span) { return $u.L + $t }
        $t -= $u.Span
    }
    return $script:x
}

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

$fRun1   = New-Frame 'iVBORw0KGgoAAAANSUhEUgAAACQAAAAaCAYAAADfcP5FAAABi0lEQVR4nNWXsa2DMBCGf56oEQU9ygB0DECRAahS0LFAhnkL0FGkYoBXMAAdA0T0FMgLkOrQYWxsEhPp/VKUIJ/Nl9++OwD+i6IwmKMwmOXfZ8vTwTRlBgDIqxZFGgMA6m7AOAnlHFf6MQU0ZYZbcgEAFGmMKAzm+zU5za0NELmTV61yQpHGqLsBZ0GtgPhW0feezoDyVTBcedVinISnGienfv96Z+fK18EQiKsb2Wq1ZY/+iUf/3ATp3CO53LrFAbnOcHdUQARedwOKNIarbVscGifh8Y9pIi8FLrPO6l+ZtgyAtkxwjZPwOLjKVWdANiJoqvwqsK8CcTCdW8bW4RqGiztDcEagsyVDfR1IVXA/OkNUfyjtdVLF2VR/f29QFk/tW3LZTXV6Yqi7Ybm20SEgAEuj5ddyjDx+5GnTOss+abbjJLy8atGU2aZFHQbSSdWEj4zrZAXEF4/CYKb+pXNsnIRHTZc78i7k6ub3a7J646A3EJP1qjjVerLeOtQu42TtTjJl01HZrPcCQ772jgRv1j0AAAAASUVORK5CYII='
$fRun2   = New-Frame 'iVBORw0KGgoAAAANSUhEUgAAACQAAAAaCAYAAADfcP5FAAABaklEQVR4nNWWMY6DMBBFPytqREGPcoB0HCDF1iuqFHS5QKS9yl6AjiJVDrAFRUo6DhDRUyAuQKqJJs44thU7u/kSAslj+/mPPQZ4F2VpsmRpsqjfoRXpYI67DQCgrFtURQ4AaLoB4zSLfXzpwxRw3G2wXa8AAFWRI0uTZf+5DubWHRC5U9at2KEqcjTdgFBQN0A8VfR+pBBQsQTDVdYtxmmOpHZy6ue397avYh0MgfiayFY3KTv0Zxz6812Qzj2Sz9RdHVDrDHdHAiLwphtQFTl8pe3q0DjNEX9MHXkp8HnqrFZlShkAbZngGqc54uCSq96AbETQVPklsJcCcTCdW8arwzcMF3eG4IxAoaVCvRxIKrhP7SGqP3TsdZLivFZ/+kk7fX8t0rf0SLGmeWJTAIkuWF2btADbsbn+fFOregpIuohd2iU5A/FJmm54GMvbbeGs95Aq02lR/xZsx/13e8ipJvCVutQTl34XWU/czQrlyNYAAAAASUVORK5CYII='
$fRun3   = New-Frame 'iVBORw0KGgoAAAANSUhEUgAAACQAAAAaCAYAAADfcP5FAAABb0lEQVR4nOWWMW6DMBSGf1eZEQM7ygHYOAADc8XUgY0LIOUqvQAbQyYO0IGhIxsHiNg9IC5ApxcZ5zm2GpOo6idZgJ6Nf/6Hnw38FaIwWKMwWPX7vREmMV2VAQCKpkeZxgCAdpgg54Ud44s3W4euyvCRHAEAZRojCoO1zpPd3LoRRO4UTc8OKNMY7TBhL1EbQWqq6HqPPUQdODEqRdNDzovg4uTU59fo7b86mMSQEF8TubJJ2Xm84DxebjqZ3CN8pu7qgF5nVHc4QSS8HSaUaQxfabs6JOdFqM02UC0FPled01fZUgbAWCZU5LwIEm5y1JsgF0g0VX5OlLVS+6SrMnRVhnaYAPCLwSrIlzuuPNUhFUqX7tLTBdkKrlWQnBehriBT8dTh+uliTC45QYc0at+n983VJca9t86TlRqgbK429Mptit+LcehL/2U/tXcoDXWebM7e9KzHXHnYIdpcuYl/cwZ/eIc2OfCKs9T/4AftmeOdapvcmAAAAABJRU5ErkJggg=='
$fStandA = New-Frame 'iVBORw0KGgoAAAANSUhEUgAAACQAAAAaCAYAAADfcP5FAAABY0lEQVR4nNWWMY6DMBBFv1fUiIIe5QDpOECKPQDVFnS5wB4mF6CjSJUDbMEB6DhARO/C8gVIsXI0cWzsZMfZ3S8hkBiLx5/xl4H/orLIl7LIF/s5tYQP5rTfAQCabkBbVwCAfpwhlXau4dJbqOC03+FjuwEAtHWFssiXz/dtMrfugIw7TTc4F7R1hX6ckQrqBoi2ytzXlAIqc8FQNd0AqbRwvTdOHb4mtrnKfDAGhOtDsbpp2XE64zid74p87hlxtu7qgJ0z1B0XkAHvxxltXYGrbVeHpNKCXqGFNAo4d13UX4VaBsAbE1RSaWHAfY6yAcWIpr4PKpjUnKKp71MQiMudWL3UIVuujfByoKYbViMiCCSVFnQH+cLTlqsuJv2ztZcW1AJ8D2bTDejHGWunAlprnmMUBWSgfKdG118/e8L8laFeS/Vohzj1o6G2RQc1NNyP1D4NlFp/DuihMwzHLgvl0AV0KsA5iDtgcAAAAABJRU5ErkJggg=='
$fStandB = New-Frame 'iVBORw0KGgoAAAANSUhEUgAAACQAAAAaCAYAAADfcP5FAAABaklEQVR4nNWWMW6DMBSGf6rMiIEd9QBsHIAhc8WUgY0LROpVegE2hkwcoANDRzYOELF7sLgAnV7kOM99TmXS5pcskHg2H//zexh4FqVJvKZJvNr3WytywfRNCQCo2gF1kQEAunGG0gs7J5RepIC+KXHIXwEAdZEhTeL1uM83c+sGiNyp2oGdUBcZunHGVlBXQGaq6PqTtoDacTCmqnaA0kvEPSenPj6nYPtq54IhkFAv8tVVyk7TGafpfBPkco8UMnUXB+w+Y7rDARF4N86oiwyh0nZxSOklMoc00WwFIavO66uklAFwtglTSi8RgbscDQbkI4Kmzs9BiZ06pPqmRN+U6MYZAF8MIlAod3z1UIdMUbpslx4OJDVcEUjpJTIryNU8bXFxNozLJS/RIe3r/W3l7rnBxdrrHvf5SgMwfq6S6AfresZ9gM+6dun/2aZ26fmBzI0qbe57Yn8NtLX+HdBdZ5gQVSYdbb4BhALYMXNKzk8AAAAASUVORK5CYII='
$fGrazeA = New-Frame 'iVBORw0KGgoAAAANSUhEUgAAACQAAAAaCAYAAADfcP5FAAABJklEQVR4nO2UMQ6CQBBF/xJrQkFvPACdB7CwsKSisNILeBgvQEeMlQew4AB0HsDQUxAusBZmN+M6y0IUqn0JgYU/w2d2BsDj8Xg8nlGIIaI4CuXtuOnVpHnpzNO0nThtEwkA5/uDfbfT0GmbyKKq4TI0hDQvsV8v9ZozZTX0TyMm18fTaiiY24yLD0NxFMo5zah+Yg3FUSj36yWmNpPmpbWhAWBBF1myQpasPoKbthN0ytT+Ux0Hp1P5+uIEwI+1GRxH4Vd5x0Lz2cZfb5nrP6KSUePqumk7YR6cdshHaUM0eEhpf4FrZsXC9mBK+po6MPtn6uq40BVSU+GC6lwxY7SKoGk7keYliqpGUdW6OofLTtLzbJgvPlx2krsHvEefO7i8Y7SUF4mWuptmbewRAAAAAElFTkSuQmCC'
$fGrazeB = New-Frame 'iVBORw0KGgoAAAANSUhEUgAAACQAAAAaCAYAAADfcP5FAAABHUlEQVR4nO2UsQ3CMBBFzyi15cJ9xADuGICCgjJVilSwAMOwQDqEqBiAIgPQMQCidxFlAVPZOsI5jgWBxk+yZCv/Lj/nuwAkEolEIhEFGyOSgpvzdjmoKeommEe3HdutlAEA2F9u5LuDhnYrZQ7XB4QMjaGoG6gWuTtTpryGvmmkz+l29xqa/dpMiBdDUnDzSzO2n0hDUnBTLXKY2kxRN96GBgDI8KFUcyjV/CVYtx3DU2bvH+soKJ3NNxTHAOix7gdLwd/KGwvO5xt/d2Wh/4hNho3bvW471l+UdsxHOUM4eExpP4FqZkvmezAlQ0096/fP1NUJ4SpkpyIE1oViYrTOkG47VtSNu9N/VsexOa6N74z3UnBDLSpnjBbzBIrtq2s/uDK/AAAAAElFTkSuQmCC'
$fPoopA  = New-Frame 'iVBORw0KGgoAAAANSUhEUgAAACQAAAAaCAYAAADfcP5FAAABYklEQVR4nO2WMW6DQBBFPxE1oqBHPoA7DkCROqJyQccFIvkquQAdhSsOkIIiJR0HsOi3QFyAVCONYdYDzmIlUr60AonZ5e2f2QHgrygKgykKg2l+v7c8G0xdpACArGyQJzEAoGp7mGEU57jSixZQFylOxwMAIE9iRGEwvb8ed3NrAUTuZGUjTsiTGFXbYy+oGyCeKrre0x5QvgTDlZUNzDB60nNy6uOzc1ZXvg2GQFy9SBJ3mDZ1k7JLd8Wluy4m2tyTFv4JDMCO/bzPcHckIAKv2h55EmNL2mwwAHPIDKPHh7YobwWPnjppE6t2paUMgLVNcJlh9Ajc5qgzoDUi6HsZUDu1S9VFirpIF/XKpQK5cmetnurQGj0dSGu4KpAZRo+fIFvznEuKc9r96Sft6/w2SffSkGK19/haAIk+sLZn0gbWrs31X9SaNgPxQtWKe0vsw0B769cBbeoJLk6Z1oe+AWp805cuROOIAAAAAElFTkSuQmCC'
$fPoopB  = New-Frame 'iVBORw0KGgoAAAANSUhEUgAAACQAAAAaCAYAAADfcP5FAAABcklEQVR4nO2WsWqEQBCGf8PVYmEvPsB1PoBwqYNVCjuLawN5lbQp7Cyu8gESsEhp5wOIvYX4AptqYU5nHb2sRwL5QU64Wf32n50fgb8i33OV77lqer+3HBNMmcUAgCSvkEYBAKCoO/TDyK6xpQepoMxiPB9DAEAaBfA9V708Hndzawak3Unyil2QRgGKusNeUFdAtFX6d0l7QB04GKokr9APo8P9r516+2isnauDCUaD2HoRJ+qw3tRVyy5Ni0vTzhaa3OMe/BMYgIz9NGeoOxyQBi/qDmkUYEvbTDAAcagfRode0kNpFNw6ddwmVu1KahkAY0xQ9cPoaHCTo9aA1khDL3VATGqbKrMYZRbPziuVCGTLnbW6q0NrdHcgKXBFoH4YHTpBpvCciquzmv76I+3r9Ulx99zF1UrvWd2ypZ1NQ1Vy4XwKb5+yPfT+2f6OHNI6n0JlcmkzED2o0uHmaikIB/WfQ5I2ZYJpbLmp2lJL9Q0s8OePskCXqQAAAABJRU5ErkJggg=='
$fPile   = New-Frame 'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAFCAYAAAB4ka1VAAAARklEQVR4nGNgQAJmalL/zdSk/iOLsSBL6suyQ3lS/0/desbIwMDAwIQpycCgL8vOADOJEV0SGVx8/JOBEWYCNgWnbj1jBAAtYBRk5cgKRQAAAABJRU5ErkJggg=='

# 질주 사이클: 뻗음 -> 지나감 -> 모음 -> 지나감 (반복)
$runCycle = @($fRun1, $fRun2, $fRun3, $fRun2)

# ---------- 창 설정 (투명, 항상 위, 작업표시줄에 안 뜸) ----------
$window = New-Object System.Windows.Window
$window.WindowStyle        = 'None'
$window.AllowsTransparency = $true
$window.Background         = [System.Windows.Media.Brushes]::Transparent
$window.Topmost            = $true
$window.ShowInTaskbar      = $false
$window.ShowActivated      = $false
$window.SizeToContent      = 'WidthAndHeight'

# ---------- 말풍선 + 말 ----------
$panel = New-Object System.Windows.Controls.StackPanel
$panel.Orientation = 'Vertical'

$bubbleText = New-Object System.Windows.Controls.TextBlock
$runNeigh = New-Object System.Windows.Documents.Run('히힝~ ')
$runHeart = New-Object System.Windows.Documents.Run([string][char]0x2665)
$runHeart.Foreground = [System.Windows.Media.Brushes]::Crimson
[void]$bubbleText.Inlines.Add($runNeigh)
[void]$bubbleText.Inlines.Add($runHeart)
$bubbleText.FontSize = 14

$bubble = New-Object System.Windows.Controls.Border
$bubble.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromArgb(235, 255, 255, 255))
$bubble.CornerRadius = New-Object System.Windows.CornerRadius(10)
$bubble.Padding = New-Object System.Windows.Thickness(9, 4, 9, 4)
$bubble.Margin = New-Object System.Windows.Thickness(0, 0, 0, 5)
$bubble.HorizontalAlignment = 'Center'
$bubble.Visibility = 'Hidden'
$bubble.Child = $bubbleText

$horse = New-Object System.Windows.Controls.Image
$horse.Source = $fStandA
$horse.Width  = 144   # 원본 36px -> 4배 확대
$horse.Height = 104
$horse.HorizontalAlignment = 'Center'
[System.Windows.Media.RenderOptions]::SetBitmapScalingMode($horse, 'NearestNeighbor')

$scale = New-Object System.Windows.Media.ScaleTransform(1, 1)
$horse.RenderTransform = $scale
$horse.RenderTransformOrigin = '0.5,0.5'

[void]$panel.Children.Add($bubble)
[void]$panel.Children.Add($horse)
$window.Content = $panel

# ---------- 바닥에 남는 응가 ----------
$script:piles = New-Object System.Collections.ArrayList

function New-Pile([double]$x) {
    $w = New-Object System.Windows.Window
    $w.WindowStyle = 'None'; $w.AllowsTransparency = $true
    $w.Background = [System.Windows.Media.Brushes]::Transparent
    $w.Topmost = $true; $w.ShowInTaskbar = $false; $w.ShowActivated = $false
    $w.SizeToContent = 'WidthAndHeight'

    $img = New-Object System.Windows.Controls.Image
    $img.Source = $fPile
    $img.Width = 40; $img.Height = 25    # 8x5 -> 5배 (눈에 잘 띄게)
    [System.Windows.Media.RenderOptions]::SetBitmapScalingMode($img, 'NearestNeighbor')
    $w.Content = $img

    # 화면 밖으로 나가지 않게 + 떨어진 지점의 모니터 바닥에 배치
    if ($x -lt $script:minX) { $x = $script:minX }
    if ($x -gt $script:maxX - 40) { $x = $script:maxX - 40 }
    $w.Left = $x
    $w.Top  = (Get-GroundDip ($x + 20)) - 25

    $w.Add_MouseRightButtonDown({ $this.Close() })   # 우클릭 = 치우기
    $w.Show()

    [void]$script:piles.Add(@{ win = $w; ttl = 700 })   # 약 21초 후 자연 소멸
    if ($script:piles.Count -gt 4) {                    # 최대 4개까지만
        $old = $script:piles[0]; $script:piles.RemoveAt(0)
        try { $old.win.Close() } catch {}
    }
}

# ---------- 상태 ----------
$script:wa          = [System.Windows.SystemParameters]::WorkArea
$script:x           = [double]($script:wa.Left + $script:wa.Width / 2)
$script:groundY     = $script:wa.Bottom - 130
$script:minX        = [double]$script:wa.Left    # 창이 뜨기 전 임시값 (Loaded에서 전체 모니터로 갱신)
$script:maxX        = [double]$script:wa.Right
$script:xRanges     = , @{ L = [double]$script:wa.Left; R = [double]$script:wa.Right }
$script:dir         = -1
$script:targetX     = [double]($script:x - 600)   # 첫 달리기 목적지
$script:state       = 'run'      # run / idle / graze / poop
$script:stateTicks  = 150
$script:jumpTicks   = 0
$script:bubbleTicks = 0
$script:tick        = 0

$window.Left = $script:x
$window.Top  = $script:groundY

$window.Add_Loaded({
    try { Update-Screens } catch {}
    $script:groundY = (Get-GroundDip ($script:x + $window.ActualWidth / 2)) - $window.ActualHeight
    $window.Top = $script:groundY
})

# ---------- 애니메이션 루프 (30ms) ----------
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(30)
$timer.Add_Tick({
    $script:tick++

    # 모니터 구성/배율 변경 감지 (약 4.5초마다)
    if (($script:tick % 150) -eq 0) {
        try {
            Update-Screens
            # 화면 밖에 남겨졌으면 안으로 끌어오고, 바닥 높이도 재계산
            if ($script:x -gt $script:maxX - $window.ActualWidth) { $script:x = $script:maxX - $window.ActualWidth; $window.Left = $script:x }
            if ($script:x -lt $script:minX) { $script:x = $script:minX; $window.Left = $script:x }
            $script:groundY = (Get-GroundDip ($script:x + $window.ActualWidth / 2)) - $window.ActualHeight
        } catch {}
    }

    if ($script:jumpTicks -gt 0) {
        # 점프(장애물 넘기)
        $script:jumpTicks--
        $p = 1 - ($script:jumpTicks / 16.0)
        $offset = 60 * [math]::Sin([math]::PI * $p)
        $window.Top = $script:groundY - $offset
        $horse.Source = $fRun1
    }
    else {
        # 상태 전환
        $script:stateTicks--
        if ($script:stateTicks -le 0) {
            # 풀을 뜯고 난 뒤엔 35% 확률로 곧바로 응가
            $toPoop = ($script:state -eq 'graze' -and $script:rand.NextDouble() -lt 0.35)
            $r = $script:rand.NextDouble()
            if (-not $toPoop -and $r -ge 0.87) { $toPoop = $true }   # 평상시에도 13%

            if ($toPoop) {
                $script:state = 'poop'
                $script:stateTicks = 80                            # 약 2.4초
                $runNeigh.Text = '뿌지직...'
                $runHeart.Text = ''
                $bubble.Visibility = 'Visible'
                $script:bubbleTicks = 80
            }
            elseif ($r -lt 0.42) {
                $script:state = 'run'
                # 실제 모니터 영역 안에서 무작위 목적지를 골라 그쪽으로 달림
                $script:targetX = Get-RandomTargetX
                if ($script:targetX -gt $script:x) { $script:dir = 1 } else { $script:dir = -1 }
                $script:stateTicks = 2000                          # 상한 (목적지 도달 시 조기 종료)
            }
            elseif ($r -lt 0.62) {
                $script:state = 'idle'
                $script:stateTicks = $script:rand.Next(60, 180)
            }
            else {
                $script:state = 'graze'
                $script:stateTicks = $script:rand.Next(160, 320)   # 느긋하게 풀 뜯기
            }
        }

        switch ($script:state) {
            'run' {
                $script:x += 3.4 * $script:dir
                if ($script:x -lt $script:minX) { $script:x = $script:minX; $script:dir = 1 }
                $edgeX = $script:maxX - $window.ActualWidth
                if ($script:x -gt $edgeX) { $script:x = $edgeX; $script:dir = -1 }
                # 모니터 사이 빈 공간(어느 모니터에도 안 보이는 구간)이면 진행 방향의 다음 모니터로 건너뜀
                $c = $script:x + $window.ActualWidth / 2
                $inside = $false
                foreach ($rg in $script:xRanges) { if ($c -ge $rg.L -and $c -le $rg.R) { $inside = $true; break } }
                if (-not $inside) {
                    if ($script:dir -gt 0) {
                        foreach ($rg in $script:xRanges) { if ($rg.L -gt $c) { $script:x = $rg.L; break } }
                    }
                    else {
                        for ($i = $script:xRanges.Count - 1; $i -ge 0; $i--) {
                            if ($script:xRanges[$i].R -lt $c) { $script:x = $script:xRanges[$i].R - $window.ActualWidth; break }
                        }
                    }
                }
                # 목적지에 도착하면 다음 행동으로
                if ([math]::Abs($script:x - $script:targetX) -lt 6) { $script:stateTicks = 1 }
                $window.Left = $script:x
                # 지금 밟고 있는 모니터의 바닥 높이에 맞춤
                $script:groundY = (Get-GroundDip ($script:x + $window.ActualWidth / 2)) - $window.ActualHeight
                $window.Top  = $script:groundY
                $step = [int]([math]::Floor($script:tick / 3)) % 4
                $horse.Source = $runCycle[$step]
                if ($script:dir -gt 0) { $scale.ScaleX = -1 } else { $scale.ScaleX = 1 }
            }
            'idle' {
                $window.Top = $script:groundY
                if (($script:tick % 45) -lt 8) { $horse.Source = $fStandB }
                else { $horse.Source = $fStandA }
                # 가끔 히힝 울기
                if ($script:bubbleTicks -le 0 -and $script:rand.NextDouble() -lt 0.006) {
                    $runNeigh.Text = '히히힝~!'
                    $runHeart.Text = ''
                    $bubble.Visibility = 'Visible'
                    $script:bubbleTicks = 45
                }
            }
            'graze' {
                $window.Top = $script:groundY
                # 우물우물 (풀이 줄었다 다시 수북)
                if (($script:tick % 16) -lt 8) { $horse.Source = $fGrazeA }
                else { $horse.Source = $fGrazeB }
            }
            'poop' {
                $window.Top = $script:groundY
                if ($script:stateTicks -gt 40) { $horse.Source = $fPoopA }   # 꼬리 들기
                else { $horse.Source = $fPoopB }                              # 볼일 중
                if ($script:stateTicks -le 1) {
                    # 엉덩이 쪽 바닥에 응가를 남김 (그림 기본방향: 엉덩이는 오른쪽)
                    if ($scale.ScaleX -eq 1) { $px = $window.Left + $window.ActualWidth - 42 }
                    else { $px = $window.Left + 2 }
                    try { New-Pile $px } catch {}
                    # 말풍선 원상복구 후, 볼일 다 봤으면 반대쪽으로 도망!
                    $runNeigh.Text = '히힝~ '
                    $runHeart.Text = [string][char]0x2665
                    $script:state = 'run'
                    $script:dir = -$script:dir
                    # 반대 방향 화면 끝까지 도망!
                    if ($script:dir -gt 0) { $script:targetX = $script:maxX - $window.ActualWidth }
                    else { $script:targetX = $script:minX }
                    $script:stateTicks = 2000
                }
            }
        }
    }

    # 응가 수명 관리
    if ($script:piles.Count -gt 0) {
        for ($i = $script:piles.Count - 1; $i -ge 0; $i--) {
            $p = $script:piles[$i]
            $p.ttl--
            if ($p.ttl -le 0 -or -not $p.win.IsVisible) {
                try { $p.win.Close() } catch {}
                $script:piles.RemoveAt($i)
            }
            elseif ($p.ttl -lt 60) {
                $p.win.Opacity = $p.ttl / 60.0    # 서서히 사라짐
            }
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
    if ($script:jumpTicks -le 0 -and $script:state -ne 'poop') { $script:jumpTicks = 16 }
    if ($script:state -ne 'poop') {
        $runNeigh.Text = '히힝~ '
        $runHeart.Text = [string][char]0x2665
    }
    $bubble.Visibility = 'Visible'
    $script:bubbleTicks = 35
})

$window.Add_MouseRightButtonDown({
    $timer.Stop()
    foreach ($p in $script:piles) { try { $p.win.Close() } catch {} }
    $window.Close()
})

$timer.Start()
[void]$window.ShowDialog()
