DROP FUNCTION fn_hello;
DROP ROUTINE fn_hello;
CREATE FUNCTION fn_hello () RETURNS TEXT
LANGUAGE plpgsql
AS $$
BEGIN
	RETURN 'Hello, functions';
END;
$$
--chamando com um SELECT
SELECT fn_hello();

--chamando com bloco anônimo
DO $$
DECLARE
	resultado TEXT;
BEGIN
	-- use CALL somente para procs
	--CALL fn_hello();
	-- PERFORM executa a função e descarta o seu resultado
	--PERFORM fn_hello();
	--resultado := fn_hello();
	--RAISE NOTICE '%', resultado;
	SELECT fn_hello() INTO resultado;
	RAISE NOTICE '%', resultado;

END;
$$


CREATE OR REPLACE FUNCTION fn_gerar_valor_aleatorio_entre (IN lim_inferior INT, IN lim_superior INT)
RETURNS INT AS $$
BEGIN
	RETURN FLOOR(RANDOM() * (lim_superior - lim_inferior + 1) + lim_inferior)::INT;
END
$$ LANGUAGE plpgsql;

SELECT fn_gerar_valor_aleatorio_entre(2, 10);


--responde se o valor recebido é par ou não
CREATE OR REPLACE FUNCTION fn_ehPar (IN n INT) RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
	RETURN n % 2 = 0;
END;
$$

CREATE OR REPLACE FUNCTION fn_executa (IN fn_nome_funcao_a_executar TEXT, IN n INT) RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
	resultado BOOLEAN;
BEGIN
	--SELECT fn_ehPar(4) INTO resultado;
	--EXECUTE 'SELECT ' || fn_nome_funcao_a_executar || '(' || n || ')' INTO resultado;
	--f'SELECT {fn_nome_a_executar}'
	EXECUTE format('SELECT %s (%s)', fn_nome_funcao_a_executar, n) INTO resultado;
	RETURN resultado;
END;
$$

SELECT fn_executa ('fn_ehPar', 6);

CREATE OR REPLACE FUNCTION fn_some (IN fn_funcao TEXT, VARIADIC elementos INT[])
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
	elemento INT;
	resultado BOOLEAN;
	
	-- 1, 2, 5, 6
	-- 1, 1, 3
BEGIN
	FOREACH elemento IN ARRAY elementos LOOP
		EXECUTE format('SELECT %s (%s)', fn_funcao, elemento) INTO resultado;
		IF resultado = TRUE THEN
			RETURN TRUE;
		END IF;		
	END LOOP;
	RETURN FALSE;	
END;
$$

DO $$
DECLARE 
	resultado BOOLEAN;
BEGIN
	SELECT fn_some ('fn_ehPar', 1, 2) INTO resultado;
	RAISE NOTICE '%', resultado;
	SELECT fn_some ('fn_ehPar', 1, 3, 5) INTO resultado;
	RAISE NOTICE '%', resultado;
END;
$$

	
	
	
	
	
	