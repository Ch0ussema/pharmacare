/**
 * French dictionary — single source of truth for every visible string.
 * Add new locales by mirroring this shape (see `Dictionary`).
 */
export const fr = {
  app: {
    name: "PharmaCare",
    tagline: "Gestion de pharmacie",
  },
  nav: {
    label: "Navigation principale",
    dashboard: "Tableau de bord",
    pos: "Caisse",
    products: "Produits",
    settings: "Paramètres",
  },
  common: {
    openNavigation: "Ouvrir la navigation",
    closeNavigation: "Fermer la navigation",
    collapseSidebar: "Réduire la barre latérale",
    expandSidebar: "Développer la barre latérale",
    demoMode: "Mode démo",
    currentUser: "Utilisateur connecté",
    skipToContent: "Aller au contenu",
    comingSoon: "Disponible prochainement",
    roles: {
      owner: "Propriétaire",
      pharmacist: "Pharmacien",
      cashier: "Caissier",
    },
    actions: {
      newProduct: "Nouveau produit",
    },
  },
  pages: {
    dashboard: {
      title: "Tableau de bord",
      description:
        "Vue d'ensemble de l'activité : chiffre d'affaires, ventes et état du stock.",
      emptyTitle: "Aucune donnée pour le moment",
      emptyDescription:
        "Les indicateurs s'afficheront ici dès l'enregistrement des premières ventes.",
    },
    pos: {
      title: "Caisse",
      description:
        "Recherchez un produit, composez le panier et encaissez le paiement.",
      emptyTitle: "Aucune vente en cours",
      emptyDescription: "Recherchez un produit pour commencer une vente.",
    },
    products: {
      title: "Produits",
      description:
        "Gérez le catalogue, les prix, les codes-barres et les niveaux de stock.",
      emptyTitle: "Aucun produit pour le moment",
      emptyDescription:
        "Ajoutez votre premier produit pour commencer à gérer le catalogue.",
    },
    settings: {
      title: "Paramètres",
      description:
        "Configurez l'identité de la pharmacie et les informations du ticket.",
      emptyTitle: "Aucun réglage configuré",
      emptyDescription:
        "Renseignez le nom, l'adresse et le pied de ticket de la pharmacie.",
    },
  },
  notFound: {
    code: "Erreur 404",
    title: "Page introuvable",
    description:
      "La page que vous cherchez n'existe pas ou a été déplacée. Vérifiez l'adresse ou revenez au tableau de bord.",
    action: "Retour au tableau de bord",
  },
} as const;

export type Dictionary = typeof fr;
