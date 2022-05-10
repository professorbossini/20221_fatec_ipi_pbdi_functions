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

CREATE OR REPLACE FUNCTION fn_all (fn_funcao TEXT, VARIADIC elementos INT[]) RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
	elemento INT;
	resultado BOOLEAN;
BEGIN
	FOREACH elemento IN ARRAY elementos LOOP
		EXECUTE format('SELECT %s (%s)', fn_funcao, elemento) INTO resultado;
		IF NOT resultado THEN
			RETURN FALSE;
		END IF;
	END LOOP;
	RETURN TRUE;
END;
$$

DO $$
DECLARE
	resultado BOOLEAN;
BEGIN
	SELECT fn_all ('fn_ehPar', 1, 2, 3, 4, 5, 6) INTO resultado;
	RAISE NOTICE '%', resultado;
	SELECT fn_all ('fn_ehPar', 2, 4, 6) INTO resultado;
	RAISE NOTICE '%', resultado;
END;
$$
-------------------------------------------------------------------------------------
-- criação das tabelas


-- DROP TABLE tb_conta;
-- DROP TABLE tb_tipo_conta;
-- DROP TABLE tb_item_pedido;
-- DROP TABLE tb_pedido;
-- DROP TABLE tb_cliente;

CREATE TABLE tb_cliente (
	cod_cliente SERIAL PRIMARY KEY,
	nome VARCHAR(200) NOT NULL
);

INSERT INTO tb_cliente (nome) VALUES ('João Santos'), ('Maria Andrade');
SELECT * FROM tb_cliente;

CREATE TABLE tb_tipo_conta(
	cod_tipo_conta SERIAL PRIMARY KEY,
	descricao VARCHAR(200) NOT NULL
);
INSERT INTO tb_tipo_conta (descricao) VALUES ('Conta corrente'),('Conta poupança');
SELECT * FROM tb_tipo_conta;

CREATE TABLE tb_conta(
	cod_conta SERIAL PRIMARY KEY,
	status VARCHAR(200) NOT NULL DEFAULT 'aberta',
	data_criacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	data_ultima_transacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	saldo NUMERIC(10, 2) NOT NULL CHECK (saldo >= 1000),
	cod_cliente INT NOT NULL,
	cod_tipo_conta INT NOT NULL,
	CONSTRAINT fk_cliente FOREIGN KEY (cod_cliente) REFERENCES tb_cliente(cod_cliente),
	CONSTRAINT fk_tipo_conta FOREIGN KEY (cod_tipo_conta) REFERENCES tb_tipo_conta (cod_tipo_conta)
);
SELECT * FROM tb_conta;
-------------------------------------------------------------------------------------
--criação de conta
--nome: fn_abrir_conta
--parâmetros: código cliente, saldo, código de tipo de conta
--retorno: boolean, indicando se a conta foi aberta ou não
DROP ROUTINE IF EXISTS fn_abrir_conta;
CREATE OR REPLACE FUNCTION fn_abrir_conta (IN p_cod_cliente INT, IN p_saldo NUMERIC (10, 2), IN p_cod_tipo_conta INT)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$

BEGIN
	-- INSERT INTO tb_conta (cod_cliente, saldo, cod_tipo_conta) VALUES (p_cod_cliente, p_saldo, p_cod_tipo_conta);
	INSERT INTO tb_conta (cod_cliente, saldo, cod_tipo_conta) VALUES ($1, $2, $3);
	RETURN TRUE;
EXCEPTION WHEN OTHERS THEN
	RETURN FALSE;
END;
$$

SELECT * FROM tb_cliente;
SELECT * FROM tb_tipo_conta;
DO $$
DECLARE
	v_cod_cliente INT := 4;
	v_saldo NUMERIC (10, 2) := 500;
	v_cod_tipo_conta INT := 1;
	v_resultado BOOLEAN;
BEGIN 
	SELECT fn_abrir_conta (v_cod_cliente, v_saldo, v_cod_tipo_conta) INTO v_resultado;
	RAISE NOTICE '%', format(
		'Conta com saldo R$%s%s foi aberta', 
		v_saldo, 
		CASE WHEN v_resultado THEN '' ELSE ' não' END
	);
	v_saldo := 1000;
	SELECT fn_abrir_conta (v_cod_cliente, v_saldo, v_cod_tipo_conta) INTO v_resultado;
	RAISE NOTICE '%', format(
		'Conta com saldo R$%s%s foi aberta',
		v_saldo,
		CASE WHEN v_resultado THEN '' ELSE ' não' END
	);
END;
$$
SELECT * FROM tb_conta;
-------------------------------------------------------------------------------------
-- depósito de valor
-- nome: fn_depositar
-- parâmetros: código de cliente, código de conta, valor a ser depositado
-- retorno: saldo resultante (numeric(10, 2))
DROP FUNCTION IF EXISTS fn_depositar;
CREATE OR REPLACE FUNCTION fn_depositar (IN p_cod_cliente INT, IN p_cod_conta INT, IN p_valor NUMERIC (10, 2))
RETURNS NUMERIC(10, 2)
LANGUAGE plpgsql
AS $$
DECLARE
	v_saldo_resultante NUMERIC(10, 2);
BEGIN
	UPDATE tb_conta SET saldo = saldo + p_valor WHERE cod_cliente = p_cod_cliente AND cod_conta = p_cod_conta;
	SELECT saldo FROM tb_conta WHERE cod_cliente = p_cod_cliente AND cod_conta = p_cod_conta INTO v_saldo_resultante;
	RETURN v_saldo_resultante;
END;
$$

DO $$
DECLARE
	v_cod_cliente INT := 4;
	v_cod_conta INT := 3;
	v_valor NUMERIC (10, 2) := 200;
	v_saldo_resultante NUMERIC (10, 2);
BEGIN
	SELECT fn_depositar (v_cod_cliente, v_cod_conta, v_valor) INTO v_saldo_resultante;
	RAISE NOTICE '%', format(
		'Após depositar R$%s, o saldo resultante é de R$%s',
		v_valor,
		v_saldo_resultante
	);
END;
$$
SELECT * FROM tb_conta;

	
	
	
	
	
	