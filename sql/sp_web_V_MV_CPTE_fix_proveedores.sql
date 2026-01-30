/*
  Ajuste solicitado:
  Si la cuenta empieza con 211 (proveedores), toma datos desde VT_PROVEEDORES.
  En caso contrario, usa VT_CLIENTES como antes.
*/

ALTER PROCEDURE [dbo].[sp_web_V_MV_CPTE]
	@pCliente						 nvarchar(15) = null,
	@pVendedor						 nvarchar(4) = null,
	@pFecha	     					 datetime = null,
	@pObservaciones					 NVARCHAR(250) = null,
	@pLat							 NVARCHAR(15) = null,
	@pLng							 NVARCHAR(15) = null,
	@pTC							 NVARCHAR(4) = null,
	@pResultado 					 smallint = NULL OUTPUT,
	@pMensaje 						 varchar(255) = NULL OUTPUT,
	@pIdComprobanteRES				 int = NULL OUTPUT
AS
DECLARE @IdComprobante NVARCHAR(13)
DECLARE @nombre NVARCHAR(50)
DECLARE @domicilio NVARCHAR(50)
DECLARE @calle NVARCHAR(50)
DECLARE @numero NVARCHAR(50)
DECLARE @piso NVARCHAR(50)
DECLARE @departamento NVARCHAR(50)
DECLARE @telefono NVARCHAR(100)
DECLARE @localidad NVARCHAR(50)
DECLARE @idProvincia NVARCHAR(4)
DECLARE @codigoPostal NVARCHAR(10)
DECLARE @documentoTipo NVARCHAR(4)
DECLARE @documentoNumero NVARCHAR(15)
DECLARE @condicionIva NVARCHAR(50)
DECLARE @idCondCpraVta NVARCHAR(4)
DECLARE @comentarios NVARCHAR(100)
DECLARE @idLista NVARCHAR(4)
DECLARE @vendedorCliente NVARCHAR(4)
DECLARE @clasePrecio int

SET NOCOUNT ON

IF @pTC = '' SET @pTC = 'NP'

IF @pCliente = ''
	SET @pCliente = (SELECT VALOR FROM TA_CONFIGURACION WHERE CLAVE='CUENTACONSUMIDORFINAL')

IF LEFT(@pCliente, 3) = '211'
BEGIN
	SELECT @nombre = isnull(RAZON_SOCIAL,''),
		@calle = ISNULL(CALLE,'.'),
		@numero = ISNULL(NUMERO,'.'),
		@piso = ISNULL(PISO,''),
		@departamento = ISNULL(DEPARTAMENTO,''),
		@telefono = TELEFONO,
		@localidad = LOCALIDAD,
		@idProvincia = PROVINCIA,
		@codigoPostal = CPOSTAL,
		@documentoTipo = DOCUMENTO_TIPO,
		@documentoNumero = NUMERO_DOCUMENTO,
		@condicionIva = IVA,
		@idCondCpraVta = IDCOND_CPRA_VTA,
		@clasePrecio = CLASE,
		@idLista = IDLISTA,
		@vendedorCliente = idvendedor
	FROM VT_PROVEEDORES
	WHERE CODIGO = @pCliente
END
ELSE
BEGIN
	SELECT @nombre = isnull(RAZON_SOCIAL,''),
		@calle = ISNULL(CALLE,'.'),
		@numero = ISNULL(NUMERO,'.'),
		@piso = ISNULL(PISO,''),
		@departamento = ISNULL(DEPARTAMENTO,''),
		@telefono = TELEFONO,
		@localidad = LOCALIDAD,
		@idProvincia = PROVINCIA,
		@codigoPostal = CPOSTAL,
		@documentoTipo = DOCUMENTO_TIPO,
		@documentoNumero = NUMERO_DOCUMENTO,
		@condicionIva = IVA,
		@idCondCpraVta = IDCOND_CPRA_VTA,
		@clasePrecio = CLASE,
		@idLista = IDLISTA,
		@vendedorCliente = idvendedor
	FROM VT_CLIENTES
	WHERE CODIGO = @pCliente
END

SET @domicilio = @calle + ' ' + @numero
IF (@piso <> '') SET @domicilio= @domicilio+ ' ' + LTRIM(RTRIM(@piso)) + ' Piso '
IF (@departamento <> '') SET @domicilio= @domicilio+ ' Dpto: ' +  LTRIM(RTRIM(@departamento))
IF (@condicionIva IS NULL) SET @condicionIva = '   1'

IF (@clasePrecio IS NULL)
	SET @clasePrecio = 1

SET @idComprobante = dbo.FN_OBTIENE_PROXIMO_NUMERO_CPTE (@pTC,'9999','X')

IF @pVendedor = '' OR @pVendedor IS NULL
	SET @pVendedor = @vendedorCliente

SET @pVendedor = dbo.FN_FMT_LEERCODIGO(LTRIM(RTRIM(@pVendedor)),4)
SET @idLista = dbo.FN_FMT_LEERCODIGO(LTRIM(RTRIM(@idLista)),4)

SET DATEFORMAT YMD
SET NOCOUNT ON

BEGIN TRANSACTION

BEGIN TRY
	INSERT INTO V_MV_CPTE
	(TC,IDCOMPROBANTE,IDCOMPLEMENTO,
	FECHA,FECHAESTFIN,FECHAESTINICIO,CUENTA,
	NOMBRE,DOMICILIO,TELEFONO,
	LOCALIDAD,IDPROVINCIA,CODIGOPOSTAL,
	DOCUMENTOTIPO,DOCUMENTONUMERO,CONDICIONIVA,
	IDCOND_CPRA_VTA,COMENTARIOS,IMPORTE,IMPORTE_S_IVA,
	MONEDA,IDVENDEDOR,CLASEPRECIO,UNEGOCIO_DESTINO,IdLista,IDMOTIVOCPRAVTA,IDDEPOSITO,AlicIva,ImporteIva,NEtoGravado,NetoNoGravado,Unegocio,
	FechaHora_Grabacion)
	VALUES
	(
		@pTC, @IdComprobante, 0,
		@pFecha, @pFecha, @pFecha,@pCliente,
		@Nombre, @Domicilio, isnull(@Telefono,''),
		@Localidad, @idProvincia, ltrim(@codigoPostal),
		@documentoTipo, ltrim(@documentoNumero), @condicionIva,
		@idCondCpraVta, @pObservaciones, 0, 0,
		'   1', @pVendedor, @clasePrecio, '   1', @idLista,'   1','   1',21,0,0,0,'   1', GETDATE())

	IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
	BEGIN
		ROLLBACK TRANSACTION
		SET @pIdComprobanteRES = NULL
		SET @pResultado = 21
		SET @pMensaje = 'No pudo darse de alta el pedido correctamente'
		RETURN
	END
	ELSE
	BEGIN
		COMMIT TRANSACTION

		SET @pResultado = 11
		SET @pMensaje = 'El Pedido se ha dado de alta con éxito'
		SET @pIdComprobanteRES = @@IDENTITY

		INSERT INTO S_TA_UBICACIONES_VENDEDOR (lat,long,idvendedor,fechahora,idcomprobante)
		VALUES (@pLat,@pLng,@pVendedor,GETDATE(), @IdComprobante)
	END
END TRY
BEGIN CATCH
	ROLLBACK TRANSACTION
	SET @pIdComprobanteRES = NULL
	SET @pResultado = ERROR_NUMBER()
	SET @pMensaje = ERROR_MESSAGE()
END CATCH
