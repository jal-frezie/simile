% This should be built in to the 'in_neighbours' interpretation of the
% incoming influence eventually
% First version if rectangular grid implemented by 1-d array
% in_8_nbrs([x]) --> element([x], nbr8_1d_ids('')).

% Note constructed 1-d array is never actually looped over so its
% dimensions do not matter
% in_8_nbrs([[x]]) --> element(makearray(element(makearray(element(element([[x]],place_in(1)),fmod(place_in(2)-1,column_count(''))+1),column_count('')),ceil(place_in(1)/column_count(''))),94),nbr8_2d_ids('')).
% this and its hexagon counterpart replaced by generated nbr lists

% these only needed for 1-d -- trivial 2-d versions included
% row_id --> ceil(index(1)/column_count('')).
% column_id --> int(fmod(index(1)-1,column_count(''))+1).
row_id --> index(2).
column_id --> index(1).

% Hexagon
% Unit is length of a side
hex_centre_x --> 1.7320508*(column_id('')+(row_id()'%'2)/2).
hex_centre_y --> 1.5*row_id('').

hex_vertices_x --> hex_centre_x('') + 1.7320508*[0,0.5,0.5,0,-0.5,-0.5].
hex_vertices_y --> hex_centre_y('') + [1,0.5,-0.5,-1,-0.5,0.5].

% in_6_nbrs([[x]]) --> element(makearray(element(makearray(element(element([[x]],place_in(1)),fmod(place_in(2)-1,column_count(''))+1),column_count('')),ceil(place_in(1)/column_count(''))),94),nbr6_2d_ids('')).

% Sexual reproduction
gamete([gene]) --> element([gene],floor(rand(1,3))).
zygote([gene_m], [gene_f]) --> [gamete([gene_m]),gamete([gene_f])].