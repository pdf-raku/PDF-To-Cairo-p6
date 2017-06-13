use v6;

class PDF::To::Cairo {

# A draft renderer for PDF to PNG
# AIM is preview output for PDF::Content generated PDF's
# 
    use Cairo;
    use Color;
    use PDF::Content::Ops :OpCode, :LineCaps, :LineJoin;
    has PDF::Content::Ops $!gfx;
    use PDF::Content::Font;
    use PDF::Content::Util::Font;
    has $.content is required handles <width height>;
    has Cairo::Surface $.surface = Cairo::Image.create(Cairo::FORMAT_ARGB32, self.width, self.height);
    has Cairo::Context $.ctx = Cairo::Context.new($!surface);
    has $.current-font;
    has Hash @!save;
    has Numeric $!tx = 0.0;
    has Numeric $!ty = 0.0;

    method TWEAK() {
        $!content.render: sub ($op, *@args, :$obj) { self.callback($op, |@args, :$obj) };
    }

    method !init {
        $!ctx.translate(0, self.height);
        $!ctx.line_width = $!gfx.LineWidth;
        $!ctx.rgb(1.0, 1.0, 1.0);
        $!ctx.paint;
    }

    method !coords(Numeric \x, Numeric \y) {
        (x, -y);
    }

    method !set-color($_, $alpha) {
        my ($cs, $colors) = .kv;
        given $cs {
            when 'DeviceRGB' {
                $!ctx.rgba( |$colors, $alpha );
            }
            when 'DeviceGray' {
                my @rgb = $colors[0] xx 3;
                $!ctx.rgba( |@rgb, $alpha );
            }
            when 'DeviceCMYK' {
                my Color $color .= new: :cmyk($colors);
                my @rgb = $color.rgb.map: * / 255;
                $!ctx.rgba( |@rgb, $alpha );
            }
            default {
                warn "can't handle colorspace: $_";
            }
        }
    }

    method !set-stroke-color { self!set-color($!gfx.StrokeColor, $!gfx.StrokeAlpha) }
    method !set-fill-color { self!set-color($!gfx.FillColor, $!gfx.FillAlpha) }

    method Save()      {
        $!ctx.save;
        @!save.push: %( :$!current-font );
    }
    method Restore()   {
        $!ctx.restore;
        if @!save {
            with @!save.pop {
                $!current-font = .<current-font>;
            }
        }
    }
    method ClosePath() { $!ctx.close_path; }
    method Stroke()    {
        self!set-stroke-color;
        $!ctx.stroke;
    }
    method Fill(:$preserve=False)    {
        self!set-fill-color;
        $!ctx.fill(:$preserve);
    }
    method FillStroke {
        self.Fill(:preserve);
        self.Stroke;
    }
    method SetStrokeRGB(*@) {}
    method SetFillRGB(*@) {}
    method SetStrokeCMYK(*@) {}
    method SetFillCMYK(*@) {}
    method SetStrokeGray(*@) {}
    method SetFillGray(*@) {}
    method EndPath() { $!ctx.new_path }

    method MoveTo(Numeric $x, Numeric $y) {
        $!ctx.move_to: |self!coords($x,$y);
    }

    method LineTo(Numeric $x, Numeric $y) {
        $!ctx.line_to: |self!coords($x,$y);
    }

    method SetLineCap(UInt $lc) {
        $!ctx.line_cap = do given $lc {
            when ButtCaps   { Cairo::LineCap::LINE_CAP_BUTT }
            when RoundCaps  { Cairo::LineCap::LINE_CAP_ROUND }
            when SquareCaps { Cairo::LineCap::LINE_CAP_SQUARE }
        }
    }

    method SetLineJoin(UInt $lc) {
        $!ctx.line_join = do given $lc {
            when MiterJoin  { Cairo::LineJoin::LINE_JOIN_MITER }
            when RoundJoin  { Cairo::LineJoin::LINE_JOIN_ROUND }
            when BevelJoin  { Cairo::LineJoin::LINE_JOIN_BEVEL }
        }
    }

    method SetDashPattern(Array $pattern, Numeric $phase) {
        $!ctx.set_dash($pattern, $pattern.elems, $phase);
    }

    method SetLineWidth(Numeric $lw) {
        $!ctx.line_width = $lw;
    }

    method CurveTo(Numeric $x1, Numeric $y1, Numeric $x2, Numeric $y2, Numeric $x3, Numeric $y3) {
        my \c1 = |self!coords($x1, $y1);
        my \c2 = |self!coords($x2, $y2);
        my \c3 = |self!coords($x3, $y3);
        $!ctx.curve_to(|c1, |c2, |c3);
    }

    method CurveToInitial(Numeric $x1, Numeric $y1, Numeric $x2, Numeric $y2) {
        my \c1 = |self!coords($x1, $y1);
        my \c2 = |self!coords($x2, $y2);
        $!ctx.curve_to(|c1, |c2, |c2);
    }

    method Rectangle(Numeric $x, Numeric $y, Numeric $w, Numeric $h) {
        $!ctx.rectangle( |self!coords($x, $y), $w, - $h);
    }

    method !concat-matrix(Num(Numeric) $scale-x, Num(Numeric) $skew-x,
                           Num(Numeric) $skew-y, Num(Numeric) $scale-y,
                           Num(Numeric) $trans-x, Num(Numeric) $trans-y) {

        my $transform = Cairo::cairo_matrix_t.new(
            :xx($scale-x), :yy($scale-y),
            :yx(-$skew-x), :xy(-$skew-y),
            :x0($trans-x), :y0(-$trans-y),
            );

        $!ctx.transform( $transform );
    }
    method ConcatMatrix(*@matrix) {
        self!concat-matrix(|@matrix);
    }
    method BeginText() { }
    has %!font-cache;
    method SetFont($font-key, $font-size) {
        $!ctx.set_font_size($font-size);
        with $!gfx.resource-entry('Font', $font-key) {
            $!current-font = %!font-cache{$font-key} //= PDF::Content::Font.from-dict($_);
            my $cairo-weight = $!current-font.Weight eq 'Bold'
                ?? Cairo::FontWeight::FONT_WEIGHT_BOLD
                !! Cairo::FontWeight::FONT_WEIGHT_NORMAL;
            my $cairo-slant = $!current-font.ItalicAngle
                ?? Cairo::FontSlant::FONT_SLANT_ITALIC
                !! Cairo::FontSlant::FONT_SLANT_NORMAL;
            $!ctx.select_font_face($!current-font.FamilyName, $cairo-weight, $cairo-slant);
        }
        else {
            warn "unable to locate Font in resource dictionary: $font-key";
            $!current-font = PDF::Content::Util::Font.core-font('courier');
            $!ctx.select_font_face('courier', Cairo::FontWeight::FONT_WEIGHT_NORMAL, Cairo::FontSlant::FONT_SLANT_NORMAL);
        }
    }
    method SetTextMatrix(*@) {
        $!tx = 0.0;
        $!ty = 0.0;
    }
    method TextMove(Numeric, Numeric) {
        $!tx = 0.0;
        $!ty = 0.0;
    }
    method SetTextRender(Int) { }
    method !show-text($text) {
        my \text-render = $!gfx.TextRender;
        given text-render {
            when 0 { # normal
                self!set-fill-color;
                $!ctx.show_text($text);
            }
            when 3 { # invisible
            }
            default { # other modoes
                my \add-to-path = ?(text-render == 4|5|7);
                my \fill = ?(text-render == 0|2|4|6);
                my \stroke = ?(text-render == 1|2|5|6);

                $!ctx.text_path($text);

                if fill {
                    self!set-fill-color;
                    $!ctx.fill: :preserve(stroke||add-to-path);
                }

                if stroke {
                    self!set-stroke-color;
                    $!ctx.stroke: :preserve(add-to-path);
                }
           }
        }
    }

    method ShowText($text-encoded) {
        $!ctx.save;
        self!concat-matrix(|$!gfx.TextMatrix);
        $!ctx.move_to($!tx,$!ty - $!gfx.TextRise);
        my $text = $!current-font.decode($text-encoded, :str);
        self!show-text: $text;
        $!tx += $!ctx.text_extents($text).x_advance;
        $!ty += $!ctx.text_extents($text).y_advance;
        $!ctx.restore;
    }
    method ShowSpaceText(List $text) {
        $!ctx.save;
        self!concat-matrix(|$!gfx.TextMatrix);
        my Numeric $font-size = $!gfx.Font[1];
        my Numeric $text-rise = $!gfx.TextRise;
        for $text.list {
            $!ctx.move_to($!tx, $!ty - $text-rise);
            when Str {
                my $text = $!current-font.decode($_, :str);
                self!show-text: $text;
                $!tx += $!ctx.text_extents($text).x_advance;
                $!ty += $!ctx.text_extents($text).y_advance;
            }
            when Numeric {
                $!tx -= $_ * $font-size / 1000;
            }
        }
        $!ctx.restore;
    }
    method SetTextLeading($) { }
    method SetTextRise($) { }
    method TextNextLine() {
        $!tx = 0.0;
        $!ty = 0.0;
    }
    method TextMoveSet($!tx, Numeric) {
        $!ty = 0.0;
    }
    method MoveShowText($text-encoded) {
        $!tx = 0.0;
        $!ty = 0.0;
        self.ShowText($text-encoded);
    }
    method MoveSetShowText(Numeric, Numeric, $text-encoded) {
        self.MoveShowText($text-encoded);
    }
    method EndText() { }

    method BeginMarkedContent(Str) { }
    method BeginMarkedContentDict(Str, Hash) { }
    method EndMarkedContent() { }

    method callback($op, *@args, :$obj) {
        without $!gfx {$!gfx = $obj; self!init};
        my $method = OpCode($op).key;
        self."$method"(|@args);
    }

    our %nyi;
    method FALLBACK($name, *@args) { %nyi{$name} //= do {warn "can't do: $name\(@args[]\) yet";} }
}
