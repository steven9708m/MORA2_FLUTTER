import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grupo_juvenil_morados/attendance_export.dart';

void main() {
  test('genera un libro analítico con resumen y detalle tipado', () {
    final bytes = createAttendanceWorkbook(
      rows: [
        AttendanceExportRow(
          activityId: 'actividad-1',
          activityName: 'Parking Virtual',
          activityDate: DateTime(2026, 6, 10),
          activityStatus: 'Cerrada',
          jovenId: 'joven-1',
          jovenName: 'Ana Pérez',
          attended: true,
          leaderId: 'lider-1',
          leaderName: 'María López',
          zone: 'Zona 1',
          age: 17,
          phone: '6000-0000',
          updatedAt: DateTime(2026, 6, 10, 20, 30),
        ),
        AttendanceExportRow(
          activityId: 'actividad-1',
          activityName: 'Parking Virtual',
          activityDate: DateTime(2026, 6, 10),
          activityStatus: 'Cerrada',
          jovenId: 'joven-2',
          jovenName: 'Luis Gómez',
          attended: false,
          leaderId: 'lider-1',
          leaderName: 'María López',
          zone: 'Zona 1',
          age: 16,
          phone: '',
          updatedAt: DateTime(2026, 6, 10, 20, 31),
        ),
      ],
      scopeTitle: 'Actividad puntual',
      filterDescription: 'Parking Virtual · 2026-06-10',
      includeContactData: true,
      includeIdentifiers: true,
    );

    expect(bytes, isNotEmpty);
    final workbook = Excel.decodeBytes(bytes);
    expect(workbook.tables.keys, containsAll(['Resumen', 'Asistencia']));
    expect(workbook.tables.keys, isNot(contains('Sheet1')));

    final summary = workbook.tables['Resumen']!;
    expect(
      summary.cell(CellIndex.indexByString('B9')).value,
      IntCellValue(2),
    );
    expect(
      summary.cell(CellIndex.indexByString('B10')).value,
      IntCellValue(1),
    );

    final detail = workbook.tables['Asistencia']!;
    expect(
      detail.cell(CellIndex.indexByString('A4')).value,
      TextCellValue('Fecha'),
    );
    expect(
      detail.cell(CellIndex.indexByString('H5')).value,
      TextCellValue('Presente'),
    );
    expect(
      detail.cell(CellIndex.indexByString('H6')).value,
      TextCellValue('No asistió'),
    );
    expect(
      detail.cell(CellIndex.indexByString('N4')).value,
      TextCellValue('ActivityId'),
    );
    expect(
      detail.cell(CellIndex.indexByString('A5')).value,
      isA<DateCellValue>(),
    );
  });
}
