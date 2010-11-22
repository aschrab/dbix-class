package # hide from PAUSE
    DBICTest::Schema::Artwork_to_Artist;

use base qw/DBICTest::BaseResult/;

__PACKAGE__->table('artwork_to_artist');
__PACKAGE__->add_columns(
  'artwork_cd_id' => {
    data_type => 'integer',
    is_foreign_key => 1,
  },
  'artist_id' => {
    data_type => 'integer',
    is_foreign_key => 1,
  },
);
__PACKAGE__->set_primary_key(qw/artwork_cd_id artist_id/);
__PACKAGE__->belongs_to('artwork', 'DBICTest::Schema::Artwork', 'artwork_cd_id');
__PACKAGE__->belongs_to('artist', 'DBICTest::Schema::Artist', 'artist_id');

__PACKAGE__->belongs_to('artist_test_m2m', 'DBICTest::Schema::Artist',
                        sub {
                            sub {
                                my $args = shift;
                                return (
                                    { "$args->{foreign_alias}.artistid" => { -ident => "$args->{self_alias}.artist_id" },
                                      "$args->{foreign_alias}.rank"     => { '<' => 10 },
                                    },
                                    $args->{self_rowobj} && {
                                        "$args->{foreign_alias}.artistid" => $args->{self_rowobj}->artist_id,
                                        "$args->{foreign_alias}.rank"   => { '<' => 10 },
                                    }
                                    );
                            }
                        });

__PACKAGE__->belongs_to('artist_test_m2m_noopt', 'DBICTest::Schema::Artist',
                        sub {
                            sub {
                                my $args = shift;
                                return (
                                    { "$args->{foreign_alias}.artistid" => { -ident => "$args->{self_alias}.artist_id" },
                                      "$args->{foreign_alias}.rank"     => { '<' => 10 },
                                    }
                                    );
                            }
                        });

1;
