use v6;
use Test;
use PDF::Lite;
use PDF::To::Cairo;
use PDF::Content::Util::TransformMatrix;

my $pdf = PDF::Lite.new;
my $page = $pdf.add-page;
my $feed = PDF::To::Cairo.new: :content($page);
my $gfx = $page.gfx;

$gfx.Save;
$gfx.MoveTo(175, 720);
$gfx.LineTo(175, 700);
$gfx.CurveToInitial( 300, 800,  400, 720 );
$gfx.ClosePath;
$gfx.Stroke;
$gfx.Restore;

$gfx.Save;

$gfx.MoveTo(50,50);
$gfx.LineTo(50,100);
$gfx.Stroke;

$gfx.SetStrokeRGB(1.0,.2,.2);
$gfx.ConcatMatrix: PDF::Content::Util::TransformMatrix::scale(1.2);
$gfx.MoveTo(50,50);
$gfx.LineTo(50,100);
$gfx.Stroke;

$gfx.SetStrokeRGB(.2, 1.0, .2);
$gfx.ConcatMatrix: PDF::Content::Util::TransformMatrix::translate(8,8);
$gfx.MoveTo(50,50);
$gfx.LineTo(50,100);
$gfx.Stroke;

$gfx.Save;
$gfx.SetStrokeRGB(.2, .2, 1.0);
$gfx.ConcatMatrix: PDF::Content::Util::TransformMatrix::skew(.15);
$gfx.MoveTo(50,50);
$gfx.LineTo(50,100);
$gfx.Stroke;
$gfx.ConcatMatrix: PDF::Content::Util::TransformMatrix::skew(.15);
$gfx.MoveTo(50,50);
$gfx.LineTo(50,100);
$gfx.Stroke;
$gfx.Restore;

$gfx.Save;
$gfx.SetStrokeRGB(.7, .2, .7);
$gfx.ConcatMatrix: PDF::Content::Util::TransformMatrix::rotate(.1);
$gfx.MoveTo(50,50);
$gfx.LineTo(50,100);
$gfx.Stroke;
$gfx.ConcatMatrix: PDF::Content::Util::TransformMatrix::rotate(.1);
$gfx.MoveTo(50,50);
$gfx.LineTo(50,100);
$gfx.Stroke;
$gfx.Restore;

$gfx.Restore;

$pdf.save-as: "t/00-basic.pdf";
lives-ok {$feed.surface.write_png: "t/00-basic.png"}, 'write to png';
done-testing;
