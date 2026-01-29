from datetime import datetime
from flask import request
from functions.general_customer import exec_customer_sql
from functions.responses import set_response
from .master import MasterView


class InventarioView(MasterView):

    def post(self):
        data = request.get_json() or {}
        items = data.get('items', []) or []

        observaciones = data.get('observacion', '')
        if not observaciones:
            observaciones = 'Creada desde el colector'

        id_deposito = data.get('iddeposito', '1')
        usuario = data.get('usuario', 'Colector')

        sql_header = f"""
        DECLARE @ids TABLE (IdInventario INT)

        INSERT INTO MV_INVENTARIOSCAB
            (Fecha, IdDeposito, Usuario, Observaciones, Finalizada, Filtros, Consolidado, AjusteStock)
        OUTPUT INSERTED.IdInventario INTO @ids
        VALUES
            (GETDATE(), '{id_deposito}', '{usuario}', '{observaciones}', 0, NULL, NULL, NULL)

        SELECT IdInventario FROM @ids
        """

        try:
            result, error = exec_customer_sql(sql_header, " al grabar el inventario", self.token_global, True)
        except Exception as e:
            error = True

        if error:
            self.log(str(result[0]['message']) + "\nSENTENCIA : " + sql_header)
            return set_response(None, 404, "Ocurrio un error al grabar el inventario.")

        inventario_id = result[0][0]

        for item in items:
            id_articulo = item.get('idarticulo', '')
            id_unidad = item.get('idunidad', '')
            conteo1 = item.get('conteo1', 0)
            costo = item.get('costo', 0)

            sql_detail = f"""
            INSERT INTO MV_INVENTARIOS
                (IdInventario, IdArticulo, IdUnidad, Stock, Conteo1, Conteo2, Diferencia, Costo)
            VALUES
                ({inventario_id}, '{id_articulo}', '{id_unidad}', NULL, {conteo1}, NULL, NULL, {costo})
            """

            try:
                _, error = exec_customer_sql(sql_detail, " al grabar el detalle del inventario", self.token_global, False)
            except Exception as e:
                error = True

            if error:
                self.log(str(result[0]['message']) + "\nSENTENCIA : " + sql_detail)
                return set_response(None, 404, "Ocurrio un error al grabar el detalle del inventario.")

        return set_response([{ 'idInventario': inventario_id }], 200, "Inventario grabado correctamente.")
