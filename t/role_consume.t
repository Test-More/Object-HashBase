use strict;
use warnings;
use Test::More;

BEGIN {
    eval { require Role::Tiny; 1 } or plan skip_all => 'Role::Tiny required';
    plan skip_all => "& prefix requires perl 5.10+" if $] < 5.010;
}

BEGIN {
    package My::CRole;
    use Role::Tiny;
    use Object::HashBase qw/cr/;
    $INC{'My/CRole.pm'} = __FILE__;
}

# Consumer uses +CR constant at compile time — must resolve
BEGIN {
    package My::CClass;
    use Object::HashBase qw/&My::CRole own/;

    sub uses_constants {
        my $self = shift;
        return [ $self->{+CR}, $self->{+OWN} ];
    }
}

ok(Role::Tiny::does_role('My::CClass', 'My::CRole'), 'role composed into consumer');

can_ok('My::CClass', qw/CR OWN cr own set_cr set_own new uses_constants/);
is(My::CClass::CR(), 'cr', 'CR constant copied to consumer');
is(My::CClass::OWN(), 'own', 'OWN constant');

my $obj = My::CClass->new(cr => 'role-val', own => 'own-val');
is($obj->cr, 'role-val', 'role accessor works on consumer instance');
is($obj->own, 'own-val', 'own accessor works');
is_deeply($obj->uses_constants, ['role-val', 'own-val'], '+CONSTANT resolves at compile in consumer sub');

# Conflict: consumer already has CR sub before & prefix processed
BEGIN {
    package My::ConflictRole;
    use Role::Tiny;
    use Object::HashBase qw/cflict/;
    $INC{'My/ConflictRole.pm'} = __FILE__;
}

BEGIN {
    package My::ConflictConsumer;
    sub CFLICT { 'overridden-value' }
    use Object::HashBase qw/&My::ConflictRole/;
}

is(My::ConflictConsumer::CFLICT(), 'overridden-value',
    'existing sub kept, role constant not copied over it');

# No warnings emitted
{
    my @warns;
    local $SIG{__WARN__} = sub { push @warns, @_ };
    eval q{
        package My::SilentConflict;
        sub CFLICT { 'mine' }
        use Object::HashBase qw/&My::ConflictRole/;
        1;
    } or do { fail("compile failed: $@") };
    is_deeply(\@warns, [], 'no warnings on silent conflict');
}

# attr_list includes role attrs for array-form constructor
{
    my @attrs = Object::HashBase::attr_list('My::CClass');
    is_deeply(
        [ sort @attrs ],
        [ sort qw/cr own/ ],
        'attr_list includes role + own attrs'
    );

    # Array-form constructor uses ordered attr_list
    # Order: role attrs first (composed earlier), then own
    my @ordered = Object::HashBase::attr_list('My::CClass');
    my $obj = My::CClass->new([ map { "v_$_" } @ordered ]);
    for my $a (@ordered) {
        is($obj->{$a}, "v_$a", "array-form set $a from attr_list order");
    }
}

done_testing;
