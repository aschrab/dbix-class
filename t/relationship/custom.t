use strict;
use warnings;

use Test::More;
use Test::Exception;
use lib qw(t/lib);
use DBICTest;
use DBIC::SqlMakerTest;

my $schema = DBICTest->init_schema();

my $artist  = $schema->resultset("Artist")->create({ name => 'Michael Jackson', rank => 20 });
my $artist2 = $schema->resultset("Artist")->create({ name => 'Chico Buarque', rank => 1 }) ;
my $artist3 = $schema->resultset("Artist")->create({ name => 'Ziraldo', rank => 1 });
my $artist4 = $schema->resultset("Artist")->create({ name => 'Paulo Caruso', rank => 20 });

my @artworks;

foreach my $year (1975..1985) {
  my $cd = $artist->create_related('cds', { year => $year, title => 'Compilation from ' . $year });
  push @artworks, $cd->create_related('artwork', {});
}

foreach my $year (1975..1995) {
  my $cd = $artist2->create_related('cds', { year => $year, title => 'Compilation from ' . $year });
  push @artworks, $cd->create_related('artwork', {});
}

foreach my $artwork (@artworks) {
  $artwork->create_related('artwork_to_artist', { artist => $_ }) for ($artist3, $artist4);
}

my $cds_80s_rs = $artist->cds_80s;
is_same_sql_bind($cds_80s_rs->as_query,
                 '(SELECT me.cdid, me.artist, me.title, me.year, me.genreid, me.single_track FROM cd me'.
                 ' WHERE ( ( me.artist = ? AND ( me.year < ? AND me.year > ? ) ) ))',
                 [
                  [ 'me.artist' => 4    ],
                  [ 'me.year'   => 1990 ],
                  [ 'me.year'   => 1979 ],
                 ]);
my @cds_80s = $cds_80s_rs->all;
is(@cds_80s, 6, '6 80s cds found (1980 - 1985)');
map { ok($_->year < 1990 && $_->year > 1979) } @cds_80s;

# this is the current version, enhanced version below.
my $cds_90s_rs = $artist2->cds_90s;
is_same_sql_bind($cds_90s_rs->as_query,
                 '(SELECT cds_90s.cdid, cds_90s.artist, cds_90s.title, cds_90s.year, cds_90s.genreid,'.
                 ' cds_90s.single_track FROM artist artist__row JOIN cd cds_90s ON ( cds_90s.artist = artist__row.artistid'.
                 ' AND ( cds_90s.year < ? AND cds_90s.year > ? ) ) WHERE ( artist__row.artistid = ? ))',
                 [
                  [ 'cds_90s.year' => 2000 ],
                  [ 'cds_90s.year' => 1989 ],
                  [ 'artist__row.artistid'  => 5    ],
                 ]);

TODO: {
  local $TODO = 'enhanced aliasing in search_related';
  my $cds_90s_rs = $artist2->cds_90s;
  is_same_sql_bind($cds_90s_rs->as_query,
                   '(SELECT me.cdid, me.artist, me.title, me.year, me.genreid,'.
                   ' me.single_track FROM artist artist__row JOIN cd me ON ( me.artist = artist__row.artistid'.
                   ' AND ( me.year < ? AND me.year > ? ) ) WHERE ( artist__row.artistid = ? ))',
                   [
                    [ 'me.year' => 2000 ],
                    [ 'me.year' => 1989 ],
                    [ 'artist__row.artistid'  => 5    ],
                   ]);
}
my @cds_90s = $cds_90s_rs->all;
is(@cds_90s, 6, '6 90s cds found (1990 - 1995) even with non-optimized search');
map { ok($_->year < 2000 && $_->year > 1989) } @cds_90s;

my @cds_90s_95 = $artist2->cds_90s->search({ 'year' => 1995 });
is(@cds_90s_95, 1, '1 90s (95) cds found even with non-optimized search');
map { ok($_->year == 1995) } @cds_90s_95;

throws_ok {
  my @cds_90s_95 = $artist2->cds_90s->search({ 'me.year' => 1995 });
  is(@cds_90s_95, 1, '1 90s (95) cds found even with non-optimized search');
  map { ok($_->year == 1995) } @cds_90s_95;
} qr/no such column: me\.year/, 'should not presume "me" alias';

# search for all artists prefetching published cds in the 80s...
#####
# the join must be a prefetch, but it can't work until the collapse rewrite is finished
# (right-side vs left-side order)
#####
lives_ok {
  my @all_artists_with_80_cds = $schema->resultset("Artist")->search
    ({ 'cds_80s.cdid' => { '!=' => undef } }, { prefetch => 'cds_80s' })->all;

  is_deeply
    ([ sort ( map { $_->year } map { $_->cds_80s->all } @all_artists_with_80_cds ) ],
     [ sort (1980..1989, 1980..1985) ],
     '16 correct cds found'
    );
} 'prefetchy-fetchy-fetch';

my @all_artists_with_80_cds = $schema->resultset("Artist")->search
  ({ 'cds_80s.cdid' => { '!=' => undef } }, { join => 'cds_80s', distinct => 1 });

is_deeply(
  [ sort ( map { $_->year } map { $_->cds_80s->all } @all_artists_with_80_cds ) ],
  [ sort (1980..1989, 1980..1985) ],
  '16 correct cds found'
);



# try to create_related a 80s cd
TODO: {
  local $TODO = 'Error message needs to be more specific';
  throws_ok {
    $artist->create_related('cds_80s', { title => 'related creation 1' });
  } qr/unable to set_from_related via complex 'cds_80s' condition on column\(s\): 'year'/, 'Create failed - complex cond';
};

# now supply an explicit arg overwriting the ambiguous cond
my $id_2020 = $artist->create_related('cds_80s', { title => 'related creation 2', year => '2020' })->id;
is(
  $schema->resultset('CD')->find($id_2020)->title,
  'related creation 2',
  '2020 CD created correctly'
);

# try a default year from a specific rel
my $id_1984 = $artist->create_related('cds_84', { title => 'related creation 3' })->id;
is(
  $schema->resultset('CD')->find($id_1984)->title,
  'related creation 3',
  '1984 CD created correctly'
);

# try a specific everything via a non-simplified rel
throws_ok {
  $artist->create_related('cds_90s', { title => 'related_creation 4', year => '2038' });
} qr/unable to set_from_related - no simplified condition available for 'cds_90s'/, 'Create failed - non-simplified rel';

# Do a self-join last-entry search
my @last_track_ids;
for my $cd ($schema->resultset('CD')->search ({}, { order_by => 'cdid'})->all) {
  push @last_track_ids, $cd->tracks
                            ->search ({}, { order_by => { -desc => 'position'} })
                              ->get_column ('trackid')
                                ->next;
}

my $last_tracks = $schema->resultset('Track')->search (
  {'next_track.trackid' => undef},
  { join => 'next_track', order_by => 'me.cd' },
);

is_deeply (
  [$last_tracks->get_column ('trackid')->all],
  [ grep { $_ } @last_track_ids ],
  'last group-entry via self-join works',
);

my $artwork = $schema->resultset('Artwork')->search({},{ order_by => 'cd_id' })->first;
my @artists = $artwork->artists->all;
is(scalar @artists, 2, 'the two artists are associated');

my @artwork_artists = $artwork->artwork_to_artist->all;
foreach (@artwork_artists) {
  lives_ok {
    my $artista = $_->artist;
    my $artistb = $_->artist_test_m2m;
    ok($artista->rank < 10 ? $artistb : 1, 'belongs_to with custom rel works.');
    my $artistc = $_->artist_test_m2m_noopt;
    ok($artista->rank < 10 ? $artistc : 1, 'belongs_to with custom rel works even in non-simplified.');
  } 'belongs_to works with custom rels';
}

@artists = ();
lives_ok {
  @artists = $artwork->artists_test_m2m2->all;
} 'manytomany with extended rels in the has many works';
is(scalar @artists, 2, 'two artists');

@artists = ();
lives_ok {
  @artists = $artwork->artists_test_m2m->all;
} 'can fetch many to many with optimized version';
is(scalar @artists, 1, 'only one artist is associated');

@artists = ();
lives_ok {
  @artists = $artwork->artists_test_m2m_noopt->all;
} 'can fetch many to many with non-optimized version';
is(scalar @artists, 1, 'only one artist is associated');


done_testing;
