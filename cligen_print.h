/*
  ***** BEGIN LICENSE BLOCK *****

  Copyright (C) 2001-2022 Olof Hagsand

  This file is part of CLIgen.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

  Alternatively, the contents of this file may be used under the terms of
  the GNU General Public License Version 2 or later (the "GPL"),
  in which case the provisions of the GPL are applicable instead
  of those above. If you wish to allow use of your version of this file only
  under the terms of the GPL, and not to allow others to
  use your version of this file under the terms of Apache License version 2, indicate
  your decision by deleting the provisions above and replace them with the
  notice and other provisions required by the GPL. If you do not delete
  the provisions above, a recipient may use your version of this file under
  the terms of any one of the Apache License version 2 or the GPL.

  ***** END LICENSE BLOCK *****
*/

#ifndef _CLIGEN_PRINT_H_
#define _CLIGEN_PRINT_H_

/*
 * Prototypes
 */
int cov2cbuf(cbuf *cb, cg_obj *co, int brief);
int pt_print1(FILE *f, parse_tree *pt, int brief);
int pt_print(FILE *f, parse_tree *pt);
int co_print1(FILE *f, cg_obj *co, int brief);
int co_print(FILE *f, cg_obj *co);
int cligen_print_trees(FILE *f, cligen_handle h, int brief);
int callbacks_dump(FILE *f, cg_callback *cc0);
int co_dump(FILE *f, cg_obj *co);
int pt_dump(FILE *f, parse_tree *pt);

/* Backward compatible */
#define cligen_print(f, h, b) pt_print((f), (h), (b))

#endif /* _CLIGEN_PRINT_H_ */
