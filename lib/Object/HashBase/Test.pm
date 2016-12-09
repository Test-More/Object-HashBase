package Object::HashBase::Test;
use strict;
use warnings;

use vars qw/$NO_RUN/;

BEGIN {
    if ($NO_RUN) {
        *ok           = sub { };
        *is           = sub { };
        *is_deeply    = sub { };
        *like         = sub { };
        *done_testing = sub { };
    }
    else {
        require Test::More;
        Test::More->import;
    }
}

return 1 if $NO_RUN;

our $VERSION = '0.001';

sub warnings(&) {
    my $code = shift;
    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings => @_ };
    $code->();
    return \@warnings;
}

sub exception(&) {
    my $code = shift;
    local ($@, $!, $SIG{__DIE__});
    my $ok = eval { $code->(); 1 };
    my $error = $@ || 'SQUASHED ERROR';
    return $ok ? undef : $error;
}

BEGIN {
    $INC{'Object/HashBase/Test/HBase.pm'} = __FILE__;

    package Object::HashBase::Test::HBase;
    use Object::HashBase qw/foo bar baz/;

    Object::HashBase::Test::is(FOO, 'foo', "FOO CONSTANT");
    Object::HashBase::Test::is(BAR, 'bar', "BAR CONSTANT");
    Object::HashBase::Test::is(BAZ, 'baz', "BAZ CONSTANT");
}

BEGIN {
    package Object::HashBase::Test::HBaseSub;
    use base 'Object::HashBase::Test::HBase';
    use Object::HashBase qw/apple pear/;

    Object::HashBase::Test::is(FOO,   'foo',   "FOO CONSTANT");
    Object::HashBase::Test::is(BAR,   'bar',   "BAR CONSTANT");
    Object::HashBase::Test::is(BAZ,   'baz',   "BAZ CONSTANT");
    Object::HashBase::Test::is(APPLE, 'apple', "APPLE CONSTANT");
    Object::HashBase::Test::is(PEAR,  'pear',  "PEAR CONSTANT");
}

my $one = Object::HashBase::Test::HBase->new(foo => 'a', bar => 'b', baz => 'c');
is($one->foo, 'a', "Accessor");
is($one->bar, 'b', "Accessor");
is($one->baz, 'c', "Accessor");
$one->set_foo('x');
is($one->foo, 'x', "Accessor set");
$one->set_foo(undef);

is_deeply(
    $one,
    {
        foo => undef,
        bar => 'b',
        baz => 'c',
    },
    'hash'
);

BEGIN {
    package Object::HashBase::Test::Const::Test;
    use Object::HashBase qw/foo/;

    sub do_it {
        if (FOO()) {
            return 'const';
        }
        return 'not const'
    }
}

my $pkg = 'Object::HashBase::Test::Const::Test';
is($pkg->do_it, 'const', "worked as expected");
{
    local $SIG{__WARN__} = sub { };
    *Object::HashBase::Test::Const::Test::FOO = sub { 0 };
}
ok(!$pkg->FOO, "overrode const sub");
is($pkg->do_it, 'const', "worked as expected, const was constant");

BEGIN {
    $INC{'Object/HashBase/Test/HBase/Wrapped.pm'} = __FILE__;

    package Object::HashBase::Test::HBase::Wrapped;
    use Object::HashBase qw/foo bar/;

    my $foo = __PACKAGE__->can('foo');
    no warnings 'redefine';
    *foo = sub {
        my $self = shift;
        $self->set_bar(1);
        $self->$foo(@_);
    };
}

BEGIN {
    $INC{'Object/HashBase/Test/HBase/Wrapped/Inherit.pm'} = __FILE__;

    package Object::HashBase::Test::HBase::Wrapped::Inherit;
    use base 'Object::HashBase::Test::HBase::Wrapped';
    use Object::HashBase;
}

my $o = Object::HashBase::Test::HBase::Wrapped::Inherit->new(foo => 1);
my $foo = $o->foo;
is($o->bar, 1, 'parent attribute sub not overridden');

{
    package Foo;

    sub new;

    use Object::HashBase qw/foo bar baz/;

    sub new { 'foo' };
}

is(Foo->new, 'foo', "Did not override existing 'new' method");

BEGIN {
    $INC{'Object/HashBase/Test/HBase2.pm'} = __FILE__;

    package Object::HashBase::Test::HBase2;
    use Object::HashBase qw/foo -bar ^baz/;

    Object::HashBase::Test::is(FOO, 'foo', "FOO CONSTANT");
    Object::HashBase::Test::is(BAR, 'bar', "BAR CONSTANT");
    Object::HashBase::Test::is(BAZ, 'baz', "BAZ CONSTANT");
}

my $ro = Object::HashBase::Test::HBase2->new(foo => 'foo', bar => 'bar', baz => 'baz');
is($ro->foo, 'foo', "got foo");
is($ro->bar, 'bar', "got bar");
is($ro->baz, 'baz', "got baz");

is($ro->set_foo('xxx'), 'xxx', "Can set foo");
is($ro->foo, 'xxx', "got foo");

like(exception { $ro->set_bar('xxx') }, qr/'bar' is read-only/, "Cannot set bar");

my $warnings = warnings { is($ro->set_baz('xxx'), 'xxx', 'set baz') };
like($warnings->[0], qr/set_baz\(\) is deprecated/, "Deprecation warning");

done_testing;

1;
