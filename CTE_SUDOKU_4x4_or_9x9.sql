----------------------------------------------------------------------------------------------------------
/*
	Author: Christos Siamitros
	Date: 26/7/2020

	SUDOKU Solver

	Details:
	Brute-Force search using Common Table Expression recursion.
	The solver was first implemented and tested for a 4x4 SUDOKU grid, and then was extended for a 9x9 grid.



	PAREMETERS:
		@int_SIZE: {4, 9}			Size of SUDOKU grid. Solver is only working for 4x4 & 9x9 grids.
		@str_input_SUDOKU_vector: 

*/
----------------------------------------------------------------------------------------------------------
--PARAMETERS

DECLARE @int_SIZE INT = 9												--4 or 9 (for 4x4 or 9x9 SUDOKU)

DECLARE @str_input_SUDOKU_vector VARCHAR(81) = 
--'1....3..........'
'...6...754...5.8.1.3..7..2...6..1......7..58..9..3...6.4...9.....18..2.........3.'

----------------------------------------------------------------------------------------------------------
DECLARE @int_Vector_SIZE INT = @int_SIZE * @int_SIZE
DECLARE @int_subGRID_SIZE INT = SQRT(@int_SIZE)
DECLARE @int_subGRID_elements_exc_row1 INT = @int_subGRID_SIZE * (@int_subGRID_SIZE - 1)	--n x (n - 1) elements of the subGRID
DECLARE @int_subGRID_row_elements INT = @int_SIZE * @int_subGRID_SIZE		--Number of elements in the top subGrid row 
																			--	for 4x4 SUDOKU =  8 {top 2 subGRIDS x 4 elements each}
																			--	for 9x9 SUDOKU = 27 {top 3 subGRIDS x 9 elements each}

----------------------------------------------------------------------------------------------------------
--Validate INPUT SUDOKU Vector
IF (SELECT CASE WHEN @str_input_SUDOKU_vector NOT LIKE '%[^0-9.]%' THEN 'VALID'
				ELSE 'INVALID'
		   END) = 'INVALID'
BEGIN

	SELECT	'ERROR: Input SUDOKU Vector contains INVALID characters!'
	RETURN 
END

IF (SELECT LEN(@str_input_SUDOKU_vector)) != @int_Vector_SIZE
BEGIN
	SELECT	'ERROR: Incorrect Input SUDOKU Vector SIZE!'
	RETURN 
END

----------------------------------------------------------------------------------------------------------
--Generate Table with elements 1 to SUDOKU_size

IF Object_ID('tempDB..#series') IS NOT NULL
	DROP TABLE #series

;WITH series(pivot_i) AS
(
	--Anchor Member
	SELECT	1 AS pivot_i
	
	UNION ALL
	
	--Recursive Member
	SELECT	pivot_i + 1
	FROM	series
	WHERE	pivot_i < @int_SIZE		--Terminate Recursion Condition
)
--Output Set
SELECT	*
INTO	--DROP TABLE
		#series
FROM	series


----------------------------------------------------------------------------------------------------------
;WITH recursive_SUDOKU(sudoku_vector, blank_i) AS
(
	--Anchor Member
	SELECT	sudoku_vector,
			--Find position of first blank item
			CHARINDEX('.',sudoku_vector) AS blank_i
	FROM	(VALUES(@str_input_SUDOKU_vector)) AS INPUT(sudoku_vector)
	
	UNION ALL
	
	SELECT	sudoku_vector,
			--Find position of next blank item
			CHARINDEX('.', sudoku_vector) AS blank_i
	FROM
			(
			SELECT																								--Derive NEW sudoku_vector
					CONVERT(VARCHAR(81), CONCAT(SUBSTRING(t1.sudoku_vector, 1, t1.blank_i - 1),					--Concat sub-vector before blank item
												t2.pivot_i,														--	     with new pivot item
												SUBSTRING(t1.sudoku_vector, t1.blank_i + 1, @int_Vector_SIZE)	--	     with sub-vector after blank item
												)
							) AS sudoku_vector,
					t1.blank_i,
					
					t2.pivot_i,

					--Find SET of elements in row of blank_i
					SUBSTRING(t1.sudoku_vector, (t1.blank_i - 1) / @int_SIZE * @int_SIZE + 1, @int_SIZE) AS row_set,						
					
					--Find SET of elements in column of blank_i
					(
					SELECT	SUBSTRING(t1.sudoku_vector, ((t1.blank_i - 1) % @int_SIZE + 1) + (s1.pivot_i - 1) * @int_SIZE,1)		
					--SELECT	*
					FROM	#series s1
					FOR XML PATH('')
					)AS col_set,
					
					--Find SET of elements in the subGrid of blank_i
					(
					SELECT	SUBSTRING(t1.sudoku_vector, (((t1.blank_i - 1) / @int_subGRID_SIZE) % @int_subGRID_SIZE) * @int_subGRID_SIZE
											+ ((t1.blank_i - 1) / @int_subGRID_row_elements) * @int_subGRID_row_elements
											+ s2.pivot_i + ((s2.pivot_i - 1) / @int_subGRID_SIZE) * @int_subGRID_elements_exc_row1,
										1)
					--SELECT	*
					FROM	#series s2
					FOR XML PATH('')
					)AS subgrid_set
			FROM	recursive_SUDOKU t1
					CROSS JOIN #series t2
			)tt1
	WHERE	row_set NOT LIKE '%' + CAST(pivot_i AS VARCHAR(2)) + '%'			--pivot_i not already in the row
			AND col_set NOT LIKE '%' + CAST(pivot_i AS VARCHAR(2)) + '%'		--pivot_i not already in the column
			AND subgrid_set NOT LIKE '%' + CAST(pivot_i AS VARCHAR(2)) + '%'	--pivot_i not already in the subgrid
			AND blank_i > 0														--Terminate Recursion Condition
)
--Output Set
SELECT	* 
FROM	recursive_SUDOKU
WHERE	blank_i = 0

----------------------------------------------------------------------------------------------------------

