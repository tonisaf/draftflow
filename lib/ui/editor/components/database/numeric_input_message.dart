import 'package:flutter/widgets.dart';

import '../../../../data/model/numeric_cell_input.dart';
import '../../../../l10n/locale_controller.dart';

String numericInputMessage(BuildContext context, NumericInputIssue issue) =>
    switch (issue) {
      NumericInputIssue.number => context.l10n.numericInvalidNumber,
      NumericInputIssue.duration => context.l10n.numericInvalidDuration,
      NumericInputIssue.nonFinite => context.l10n.numericNonFinite,
      NumericInputIssue.formula => context.l10n.numericFormulaUnsupported,
      NumericInputIssue.separators => context.l10n.numericSeparators,
      NumericInputIssue.tooLarge => context.l10n.numericTooLarge,
    };
