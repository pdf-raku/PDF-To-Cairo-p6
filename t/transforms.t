use v6;
use Test;
use PDF::Lite;
use PDF::To::Cairo;
use PDF::Content::Util::TransformMatrix;
use Cairo;

my $pdf = PDF::Lite.new;
my $page = $pdf.add-page;
$page.MediaBox = [0, 0, 150, 200];
my $feed = PDF::To::Cairo.new: :content($page);
my $gfx = $page.gfx;

$gfx.Save;
is-deeply $feed.ctx.matrix, Cairo::cairo_matrix_t.new( :y0(200) ), 'matrix initial';
$gfx.ConcatMatrix(2, 0, 0, 3, 0, 0);
is-deeply $feed.ctx.matrix, Cairo::cairo_matrix_t.new( :xx(2), :yy(3), :y0(200) ), 'scale';
$gfx.Restore;
is-deeply $feed.ctx.matrix, Cairo::cairo_matrix_t.new( :xx(1), :yy(1), :y0(200) ), 'restore';

my $translate = Cairo::cairo_matrix_t.new.init( :translate, 20, -30);

$gfx.Save;
$gfx.ConcatMatrix: PDF::Content::Util::TransformMatrix::translate(20,30);
is-deeply $feed.ctx.matrix, Cairo::cairo_matrix_t.new( :x0(20), :y0(170) ), 'translate';
$gfx.Restore;

$gfx.Save;
$gfx.ConcatMatrix: PDF::Content::Util::TransformMatrix::rotate(pi/4);
my $matrix = $feed.ctx.matrix;
given $matrix {
      is-approx .xx, 0.5.sqrt, 'rotate xx';
      is-approx .yx, -0.5.sqrt, 'rotate yx';
      is-approx .xy, 0.5.sqrt, 'rotate xy';
      is-approx .yy, 0.5.sqrt, 'rotate yy';
      is-approx .x0, 0, 'rotate x0';
      is-approx .y0, 200, 'rotate y0';
}
$gfx.Restore;

done-testing;