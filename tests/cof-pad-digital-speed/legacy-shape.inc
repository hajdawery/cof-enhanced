// SPDX-License-Identifier: GPL-3.0-or-later
// Unmodified pre-correction shape function, retained as a parity fixture.
qboolean CL_CoF_PadMoveShape( float *fw, float *side, float fwscale, float sidescale )
{
	const int mode = (int)cof_pad_move_mode.value;
	float     x, y, m, dz, walk, mag;

	cof_pad.move_saturated = false;

	if( mode < 1 || mode > 2 )
		return false;

	x = (float)Joy_CoF_AxisRaw( JOY_AXIS_SIDE ) / (float)SHRT_MAX;
	y = -(float)Joy_CoF_AxisRaw( JOY_AXIS_FWD ) / (float)SHRT_MAX;
	m = sqrt( x * x + y * y );

	dz = bound( 0.0f, cof_pad_move_deadzone.value, 0.5f );
	walk = bound( dz + 0.05f, cof_pad_move_walk.value, 1.0f );

	if( m <= dz || m <= 0.0f )
		return true;

	x /= m;
	y /= m;

	if( mode == 2 )
	{
		float a = atan2( y, x );

		a = floor( a / ( M_PI_F * 0.25f ) + 0.5f ) * ( M_PI_F * 0.25f );
		x = cos( a );
		y = sin( a );
		if( fabs( x ) < 0.001f ) x = 0.0f;
		if( fabs( y ) < 0.001f ) y = 0.0f;
	}

	if( m >= walk )
	{
		mag = 1.0f;
		cof_pad.move_saturated = true;
	}
	else mag = pow(( m - dz ) / ( walk - dz ), Q_max( 0.2f, cof_pad_move_curve.value ));

	// the keys' square: the larger component of the direction becomes 1, so a
	// diagonal sends full forward AND full side like two held keys. The game
	// scales its speed by the larger of the two and caps it at the straight
	// speed (MEASURED, c_forest3: straight 225 u/s, sideways 150, keyboard
	// diagonal 187.5, the plain stick at 45 degrees 132.3). Then the diagonal
	// boost (cof_pad_move_diagonal, 1.2 = 225 / 187.5) lifts the diagonals to
	// the straight speed; it grows with the smaller component, so straight and
	// pure sideways movement stay exactly the keyboard's.
	{
		const float big = Q_max( fabs( x ), fabs( y ));
		float boost, k;

		if( big > 0.0f )
		{
			x /= big;
			y /= big;
		}

		boost = bound( 1.0f, cof_pad_move_diagonal.value, 1.5f );
		k = 1.0f + ( boost - 1.0f ) * Q_min( fabs( x ), fabs( y ));
		x *= k;
		y *= k;
	}

	*fw += y * mag * fwscale;
	*side += x * mag * sidescale;
	return true;
}
